# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/node_js'

# content.js's gist raw-link selector (extension-misc-hardening). Drives the
# REAL shipped extension/content.js in node against a purpose-built shim --
# not a general CSS engine, just enough querySelector semantics to prove the
# selector's SCOPE -- following the precedent set by
# spec/extension/viewer_sandbox_frame_spec.rb. The listener-source-check half
# of this story lives in spec/extension/live_runtime_spec.rb instead, since
# that file already drives the real sandbox.js against the real Opal runtime;
# duplicating a second sandbox.js harness here would have been the wrong
# shape. The trust-warning half (README + drop-zone prose) has no behavior to
# drive and is verified by direct read (see the story's UAT handoff note).
RSpec.describe "content.js's gist raw-link selector" do
  include NodeJS

  let(:content_source) { File.read(File.expand_path('../../extension/content.js', __dir__)) }

  # gistFileBlocks() only ever calls three selector shapes (".file-actions",
  # ".file-info a", and -- scoped onto the .file-actions element it already
  # found -- the unscoped "a[href*=\"/raw/\"]") -- all single compounds or one
  # descendant combinator -- so that is all querySelectorAll supports.
  # It throws rather than silently matching nothing if content.js ever grows a
  # selector with more than one combinator, so this shim can't go stale and
  # stay green while testing the wrong thing.
  def dom_shim
    <<~JS
      class El {
        constructor(tag, { class: cls, attrs, text } = {}) {
          this.tagName = (tag || "").toUpperCase();
          this.className = cls || "";
          this.attrs = attrs || {};
          this.textContent = text || "";
          this.children = [];
        }
        append(...kids) { kids.forEach((k) => this.children.push(k)); return this; }
        getAttribute(name) {
          return Object.prototype.hasOwnProperty.call(this.attrs, name) ? this.attrs[name] : null;
        }
        *descendants() {
          for (const child of this.children) { yield child; yield* child.descendants(); }
        }
        matchesCompound(compound) {
          let rest = compound;
          let attrFilter = null;
          const attrMatch = rest.match(/\\[([a-zA-Z-]+)\\*="([^"]*)"\\]$/);
          if (attrMatch) { attrFilter = { name: attrMatch[1], has: attrMatch[2] }; rest = rest.slice(0, attrMatch.index); }
          let cls = null;
          const clsMatch = rest.match(/\\.([a-zA-Z0-9_-]+)$/);
          if (clsMatch) { cls = clsMatch[1]; rest = rest.slice(0, clsMatch.index); }
          const tag = rest ? rest.toUpperCase() : null;
          if (tag && this.tagName !== tag) return false;
          if (cls && !this.className.split(/\\s+/).includes(cls)) return false;
          if (attrFilter) {
            const v = this.getAttribute(attrFilter.name);
            if (v == null || !v.includes(attrFilter.has)) return false;
          }
          return true;
        }
        querySelectorAll(selector) {
          const parts = selector.trim().split(/\\s+/);
          if (parts.length > 2) throw new Error("shim handles at most one descendant combinator: " + selector);
          const pool = [...this.descendants()];
          if (parts.length === 1) return pool.filter((n) => n.matchesCompound(parts[0]));
          const [a, b] = parts;
          const ancestorsOf = (target) => {
            const chain = [];
            const walk = (n, trail) => {
              if (n === target) { chain.push(...trail); return true; }
              return n.children.some((c) => walk(c, trail.concat([n])));
            };
            walk(this, []);
            return chain;
          };
          return pool
            .filter((n) => n.matchesCompound(b))
            .filter((n) => ancestorsOf(n).some((anc) => anc !== this && anc.matchesCompound(a)));
        }
        querySelector(selector) { return this.querySelectorAll(selector)[0] || null; }
      }

      // realHref lives inside .file-actions, the way GitHub actually renders
      // its Raw button. decoyHref lives in a sibling ".file-content" block --
      // the shape a gist's own rendered content (e.g. a doc that links to some
      // other gist's raw file) would take, which is exactly what a decoy is.
      function buildFileBlock({ realHref, decoyHref, name }) {
        const file = new El("div", { class: "file" });
        const actions = new El("div", { class: "file-actions" });
        if (realHref) actions.append(new El("a", { attrs: { href: realHref } }));
        file.append(actions);
        if (decoyHref) {
          const content = new El("div", { class: "file-content" });
          content.append(new El("a", { attrs: { href: decoyHref } }));
          file.append(content);
        }
        const info = new El("div", { class: "file-info" });
        if (name) info.append(new El("a", { text: name }));
        file.append(info);
        return file;
      }

      // content.js runs top-level side effects the instant it loads
      // (scheduleScan() + a MutationObserver on document.body), so `document`,
      // `location` and `MutationObserver` all need to exist BEFORE the real
      // source is pasted in below, not just inside each test's own script.
      // `currentFiles` is mutated per-test rather than redeclaring `document`,
      // since content.js's own top-level code has already captured this one.
      // setTimeout is stubbed to a no-op: content.js's load-time scheduleScan()
      // would otherwise fire scan() -> scanGistPage() against this shim's `El`
      // (which has no hasAttribute) after this program's own driver script has
      // already printed its result -- masked in production by content.js's own
      // `.catch(() => {})`, but no reason to pay the 300ms debounce or couple
      // every example to that unrelated code path.
      let currentFiles = [];
      const document = {
        body: {},
        getElementById: () => null,
        querySelectorAll: (sel) => (sel === ".file" ? currentFiles : [])
      };
      const location = { origin: "https://gist.github.com", hostname: "gist.github.com", pathname: "/user/gistid" };
      global.MutationObserver = class { constructor() {} observe() {} };
      global.setTimeout = () => 0;
    JS
  end

  def run(script)
    run_node_json(dom_shim, content_source, script)
  end

  it "picks GitHub's real Raw link over a decoy link elsewhere in the file block" do
    result = run(<<~JS)
      currentFiles = [buildFileBlock({
        realHref: "/user/gistid/raw/abc123/real.rb",
        decoyHref: "/attacker/other/raw/evil/fake.rb",
        name: "real.rb"
      })];
      console.log(JSON.stringify(gistFileBlocks().map((b) => ({ name: b.name, rawUrl: b.rawUrl }))));
    JS

    expect(result).to eq(
      [{ 'name' => 'real.rb', 'rawUrl' => 'https://gist.github.com/user/gistid/raw/abc123/real.rb' }]
    )
  end

  it 'is not fooled into treating a decoy /raw/-shaped link outside .file-actions as the Raw button' do
    result = run(<<~JS)
      currentFiles = [buildFileBlock({ realHref: null, decoyHref: "/attacker/other/raw/evil/fake.rb", name: "real.rb" })];
      console.log(JSON.stringify(gistFileBlocks()));
    JS

    expect(result).to eq([])
  end
end
