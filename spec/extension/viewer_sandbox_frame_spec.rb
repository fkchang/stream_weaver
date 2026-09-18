# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require_relative '../support/node_js'

# One sandbox frame per doc.
#
# The sandbox iframe is where a doc actually runs: compiling it installs
# window.SWRuntime, morphdom bookkeeping, and every interval/timeout or event
# listener the doc's own code registered. None of that can be uninstalled --
# there is no "unload the doc" API -- so the only reliable reset between two
# docs is discarding the whole browsing context. Re-posting "sw:render" into an
# already-used frame would layer doc B on top of doc A's still-live state.
#
# viewer.js is real shipped JS with no build step, so this runs it in node
# against a DOM shim rather than pattern-matching its source -- the same
# approach spec/canvas/form_state_harvest_spec.rb takes for emitted JS. What a
# shim cannot show is whether a real timer survives; that stays a browser check
# (see the story's UAT handoff note).
RSpec.describe 'the viewer sandbox frame lifecycle' do
  include NodeJS

  let(:viewer_source) { File.read(File.expand_path('../../extension/viewer.js', __dir__)) }

  # Models only what viewer.js actually reaches while rendering: element lookup
  # by id, listener dispatch, and -- the part under test -- iframe identity, so
  # a replaced frame is distinguishable from a reused one and every postMessage
  # is attributable to one frame. Each post also records whether that frame was
  # hidden at the time, because the order of "unhide" and "ask it to render" is
  # itself load-bearing (see the "sw:sandbox-ready" comment in viewer.js).
  #
  # One deliberate divergence from the real DOM: `hidden` is tracked as a live
  # property, while a real cloneNode copies the *attribute*. Every path here
  # sets it as a property, so the two agree, but the shim is not the browser.
  def dom_shim(search)
    <<~JS
      const posts = [];
      const frames = [];
      const messageHandlers = [];

      class Elem {
        constructor(id, attrs) {
          this.id = id;
          this.attrs = Object.assign({}, attrs || {});
          this.listeners = {};
          this.hidden = false;
          this.textContent = "";
          this.className = "";
          this.classList = { add() {}, remove() {} };
          this.parent = null;
        }
        addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
        dispatch(type) { (this.listeners[type] || []).forEach((fn) => fn({ preventDefault() {} })); }
        replaceWith(other) {
          this.removed = true;
          other.parent = this.parent;
          if (this.parent) this.parent.children[this.parent.children.indexOf(this)] = other;
        }
      }

      class Frame extends Elem {
        constructor(id, attrs) {
          super(id, attrs);
          this.serial = frames.length + 1;
          const self = this;
          this.contentWindow = {
            postMessage: (msg) => posts.push({ frame: self.serial, hiddenAtPost: self.hidden, msg: msg })
          };
          frames.push(this);
        }
        cloneNode() {
          const copy = new Frame(this.id, this.attrs);
          copy.hidden = this.hidden;
          return copy;
        }
      }

      // The #frame iframe as viewer.html declares it: sandboxed, pointed at
      // sandbox.html, and hidden until it reports itself ready.
      const body = { children: [] };
      const initialFrame = new Frame("frame", {
        id: "frame",
        src: "sandbox.html",
        sandbox: "allow-scripts allow-popups allow-popups-to-escape-sandbox"
      });
      initialFrame.hidden = true;
      initialFrame.parent = body;
      body.children.push(initialFrame);

      const elements = {
        "frame": initialFrame,
        "status": new Elem("status"),
        "source-link": new Elem("source-link"),
        "drop-zone": new Elem("drop-zone"),
        "drop-zone-error": new Elem("drop-zone-error"),
        "file-input": new Elem("file-input"),
        "doc-name": new Elem("doc-name")
      };

      const document = { title: "", getElementById: (id) => elements[id] || null };
      const window = {
        addEventListener: (type, fn) => { if (type === "message") messageHandlers.push(fn); }
      };
      const location = { search: #{search.to_json} };

      const currentFrame = () => frames[frames.length - 1];
      const deliver = (frameEl, data) =>
        messageHandlers.forEach((fn) => fn({ source: frameEl.contentWindow, data: data }));
      const tick = () => new Promise((resolve) => setTimeout(resolve, 0));
      // Ticks enough times for the microtask chains to finish, for paths that
      // await more than one promise before posting (load() awaits
      // chrome.storage.session.get, handleFile awaits file.text()).
      const settle = async () => { for (let i = 0; i < 4; i++) await tick(); };
      const drop = (name, source) => {
        const input = elements["file-input"];
        input.files = [{ name: name, text: async () => source }];
        input.dispatch("change");
      };
      const frameState = (frameEl) => ({
        serial: frameEl.serial,
        attrs: frameEl.attrs,
        hidden: frameEl.hidden,
        removed: !!frameEl.removed
      });
    JS
  end

  def run_viewer(search: '', setup: '', script:)
    program = [dom_shim(search), setup, viewer_source, script].join("\n")
    stdout, stderr, status = Open3.capture3('node', '-e', program)
    raise "node could not run viewer.js: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end

  def render_post(frame, name, source, hidden_at_post: false)
    {
      'frame' => frame,
      'hiddenAtPost' => hidden_at_post,
      'msg' => { 'type' => 'sw:render', 'source' => source, 'name' => name }
    }
  end

  describe 'the local-file drop-zone path' do
    # No chrome.* at all, so viewer.js takes its `!hasExtensionContext || !key`
    # branch into the drop zone -- the only path that renders twice in one tab.
    let(:result) do
      run_viewer(script: <<~JS)
        (async () => {
          drop("doc-a.org", "DOC A SOURCE");
          await settle();
          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          await settle();
          const afterA = { frameCount: frames.length, posts: posts.slice(), frame: frameState(currentFrame()) };

          drop("doc-b.org", "DOC B SOURCE");
          await settle();
          const afterDropB = {
            frameCount: frames.length,
            docAFrame: frameState(frames[0]),
            docBFrame: frameState(currentFrame()),
            bodySerials: body.children.map((child) => child.serial),
            posts: posts.slice()
          };

          // A late "ready" from the discarded frame must not re-drive it.
          deliver(frames[0], { type: "sw:sandbox-ready" });
          await settle();
          const afterStaleReady = posts.slice();

          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          await settle();
          console.log(JSON.stringify({ afterA, afterDropB, afterStaleReady, posts, frameCount: frames.length }));
        })();
      JS
    end

    it 'renders the first doc into the frame viewer.html already shipped' do
      expect(result['afterA']['frameCount']).to eq(1)
      expect(result['afterA']['posts']).to eq([render_post(1, 'doc-a.org', 'DOC A SOURCE')])
    end

    it 'discards the used frame and inserts a fresh one when a second doc arrives' do
      expect(result['afterDropB']['frameCount']).to eq(2)
      expect(result['afterDropB']['docAFrame']['removed']).to be true
      expect(result['afterDropB']['docBFrame']['serial']).to eq(2)
      expect(result['afterDropB']['bodySerials']).to eq([2])
    end

    it 'gives the fresh frame the same sandboxing viewer.html declares' do
      attrs = result['afterDropB']['docBFrame']['attrs']

      expect(attrs['src']).to eq('sandbox.html')
      expect(attrs['sandbox']).to eq('allow-scripts allow-popups allow-popups-to-escape-sandbox')
      expect(attrs['id']).to eq('frame')
    end

    it 'starts the fresh frame hidden, as the shipped one was' do
      expect(result['afterDropB']['docBFrame']['hidden']).to be true
    end

    it 'unhides the fresh frame before asking it to render, not after' do
      # Not cosmetic: mermaid measures real layout while handling "sw:render",
      # and a hidden frame has no layout box. Both renders must go out to a
      # visible frame.
      expect(result['posts'].map { |post| post['hiddenAtPost'] }).to eq([false, false])
      expect(result['afterA']['frame']['hidden']).to be false
    end

    it 'waits for the fresh frame to report ready instead of rendering into the old one' do
      expect(result['afterDropB']['posts'].length).to eq(1)
      expect(result['afterStaleReady'].length).to eq(1)
    end

    it 'renders the second doc into the fresh frame, leaving the first frame untouched' do
      expect(result['posts']).to eq(
        [
          render_post(1, 'doc-a.org', 'DOC A SOURCE'),
          render_post(2, 'doc-b.org', 'DOC B SOURCE')
        ]
      )
      expect(result['posts'].count { |post| post['frame'] == 1 }).to eq(1)
    end
  end

  describe 'a second doc arriving before the first one ever rendered' do
    # The frame is discarded once something has been *rendered* into it, not
    # merely once a file has been picked. Swap that for "have we dropped
    # before" and this is the case that breaks: a frame nothing ran in is still
    # pristine, and throwing it away buys a second sandbox.html load for
    # nothing.
    let(:result) do
      run_viewer(script: <<~JS)
        (async () => {
          drop("doc-a.org", "DOC A SOURCE");
          await settle();
          drop("doc-b.org", "DOC B SOURCE");
          await settle();
          const beforeReady = { frameCount: frames.length, posts: posts.slice() };

          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          await settle();
          console.log(JSON.stringify({ beforeReady, frameCount: frames.length, posts }));
        })();
      JS
    end

    it 'keeps the pristine frame and renders only the doc that won' do
      expect(result['beforeReady']['frameCount']).to eq(1)
      expect(result['beforeReady']['posts']).to be_empty
      expect(result['frameCount']).to eq(1)
      expect(result['posts']).to eq([render_post(1, 'doc-b.org', 'DOC B SOURCE')])
    end
  end

  describe 'the GitHub/Gist path' do
    # background.js opens a fresh tab per click, so this viewer renders exactly
    # one doc and must not pay for a frame it never dirtied.
    let(:result) do
      chrome_stub = <<~JS
        const chrome = {
          runtime: {},
          storage: {
            session: {
              get: async (key) => ({ [key]: { source: "GITHUB DOC SOURCE", name: "readme.org" } }),
              remove: async () => {}
            }
          }
        };
      JS

      run_viewer(search: '?key=k1&name=readme.org', setup: chrome_stub, script: <<~JS)
        (async () => {
          await settle();
          deliver(currentFrame(), { type: "sw:sandbox-ready" });
          await settle();
          console.log(JSON.stringify({ frameCount: frames.length, posts, docAFrame: frameState(frames[0]) }));
        })();
      JS
    end

    it 'renders the stashed doc without replacing the shipped frame' do
      expect(result['frameCount']).to eq(1)
      expect(result['docAFrame']['removed']).to be false
      expect(result['posts']).to eq([render_post(1, 'readme.org', 'GITHUB DOC SOURCE')])
    end
  end
end
