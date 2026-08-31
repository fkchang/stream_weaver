# frozen_string_literal: true

require 'erb'
require 'json'

module StreamWeaver
  module Canvas
    # Renders the floating "Save as doc" button + Alpine.js modal that POSTs
    # a rendered page's content to a `save-doc` endpoint, promoting it into
    # `docs/streamweaver_canvas/`. Shared by two call sites (stream_weaver-e13):
    # the live canvas page (bridge_server.rb, saving the session's current
    # push) and canvas-read's history view (reader_layout.erb, promoting an
    # already-rendered history snapshot). The two differ only in POST
    # endpoint/body shape, where the default name comes from, and a couple of
    # copy strings -- everything else (CSS, dialog structure, org-coverage
    # notice logic) was byte-near-identical and had already started to drift
    # apart before this extraction.
    module SaveDocWidget
      module_function

      # endpoint  - fetch() URL to POST {name, format[, ...extra_body_fields]} to.
      # button_title/dialog_title/hint_html - the copy that differs between callers.
      # name_init - JS expression for the Alpine `name:` field's initial value.
      #   Canvas recomputes a fresh timestamp-based name every time the dialog
      #   opens (`''`, paired with reset_name_js); the reader's default name is
      #   derived from the archived snapshot's own filename, not wall-clock
      #   "now", so it's computed once server-side and passed in as a pre-escaped
      #   JSON literal (see reader_layout.erb's `name:` line for why both
      #   `.to_json` and `ERB::Util.h` are required together).
      # reset_name_js - statement(s) run at the top of openDialog() to (re)compute
      #   `name`; empty when the initial value never needs refreshing. Skipped
      #   entirely when `gist[:prefill_name]` is present (see `gist` below) --
      #   an already-shared canvas prefills its shared name instead of a fresh
      #   timestamp, so the next save updates the same gist.
      # extra_alpine_data - extra x-data keys inserted verbatim after `name:`
      #   (canvas: the `defaultName()` method; reader: the `file:` index the
      #   snapshot lives at). JS object literals don't care about key order, so
      #   one insertion point suffices for both callers' extra state.
      # extra_body_fields - extra keys inserted verbatim into the POST JSON body,
      #   ahead of `name`/`format` (reader: `file: this.file, `).
      # host_class - extra class on the root `x-data` div, or nil. The reader
      #   needs `sw-save-doc-host` (`display: contents`) because the widget
      #   lives inside a flex row (#sw-reader-nav) and must not become a flex
      #   item itself; the canvas widget has no such host and needs none.
      # css_layer - `@layer` name to wrap the `<style>` block in, or nil. The
      #   reader's chrome is layered so it can't outrank/be outranked by
      #   framework CSS (see reader_layout.erb's scoping comment); the canvas
      #   page has no such layering scheme.
      # dialog_css_extra - extra CSS declarations appended into the
      #   `.sw-save-doc-dialog` rule (reader adds `color`/`text-align` that the
      #   canvas dialog doesn't need, having inherited page defaults already).
      # source_dir - absolute path of the repo the caller resolves "This
      #   repo" to (stream_weaver-j3b3), or nil when the caller has none to
      #   offer. When present, a scope toggle ("This repo (<basename>)" vs.
      #   "Global") is rendered above the name field, defaulting to "This
      #   repo"; when nil the toggle is omitted entirely and the save is
      #   always Global -- a manual choice, never a silent auto-resolution
      #   (canvas-doc-location-and-discovery.md).
      # gist - kwarg for the third "Gist" destination radio (share-to-gist
      #   epic), or nil when the caller has no gist capability to offer at
      #   all -- in which case the radio is omitted entirely, same as
      #   source_dir: nil for the repo radio. The scope row now renders when
      #   EITHER source_dir OR gist is present (a canvas pushed from outside
      #   a git repo can still be shared). Shape:
      #     {
      #       available: true/false,      # GistPublisher.gh_available? -- a
      #                                    # cheap presence check, NOT an auth
      #                                    # check. A missing token surfaces
      #                                    # as a save-time error, not a
      #                                    # hidden option (Gloria's Law: show
      #                                    # the capability and the one thing
      #                                    # that unblocks it).
      #       unavailable_reason: "...",  # helper text shown next to the
      #                                    # radio -- rendered disabled --
      #                                    # when available is false; unused
      #                                    # when true.
      #       known: {"doc-name" => {url:, revisions:}, ...},
      #                                    # the gist(s) relevant to THIS
      #                                    # dialog -- the caller scopes this
      #                                    # down (e.g. via GistStore
      #                                    # #latest_for_prefix for the
      #                                    # current canvas), not the whole
      #                                    # install's history, since it's
      #                                    # embedded into every page render.
      #                                    # Keyed by the doc's base name (no
      #                                    # extension). Embedded as a JSON
      #                                    # literal and looked up live, as
      #                                    # the name field
      #                                    # is edited, via the Alpine
      #                                    # currentGist() helper -- drives
      #                                    # the "already shared · N
      #                                    # revisions" hint, the URL preview
      #                                    # line, and the action button's
      #                                    # Update-gist/Create-gist label.
      #       prefill_name: "already-shared-name" or nil,
      #                                    # when a gist is already known for
      #                                    # the canvas this dialog belongs
      #                                    # to, openDialog() uses this as the
      #                                    # initial `name` INSTEAD OF the
      #                                    # caller's reset_name_js timestamp
      #                                    # logic, so the very next save
      #                                    # updates that gist rather than
      #                                    # minting a second one.
      #     }
      #   Gist is never the default scope -- This-repo/Global remain the only
      #   defaults (`scope: '#{source_dir ? 'repo' : 'global'}'` below is
      #   unchanged); gist is only ever chosen by an explicit user click.
      def render(
        endpoint:,
        button_title:,
        dialog_title:,
        hint_html:,
        name_init:,
        source_dir: nil,
        reset_name_js: '',
        extra_alpine_data: '',
        extra_body_fields: '',
        host_class: nil,
        css_layer: nil,
        dialog_css_extra: '',
        gist: nil
      )
        style_open  = css_layer ? "<style>@layer #{css_layer} {" : '<style>'
        style_close = css_layer ? '}</style>' : '</style>'
        host_css    = host_class ? "\n            .#{host_class} { display: contents; }" : ''
        host_attr   = host_class ? %( class="#{host_class}") : ''
        scope_html  = scope_toggle_html(source_dir, gist)

        # Embedded verbatim into the `x-data="{ ... }"` HTML attribute below,
        # so any quotes the JSON produces must be HTML-escaped the same way
        # reader_layout.erb's `name_init` already is (see its doc comment
        # above) or they'd terminate the attribute early. gistKnown must
        # always serialize to a JS object literal (never `null`) since it's
        # indexed by name below -- `gist[:known]` defaults to `{}` whether
        # `gist` itself, or just its `known:` key, is missing.
        gist_known = (gist && gist[:known]) || {}
        gist_known_json = ERB::Util.h(gist_known.to_json)

        gist_prefill = gist && gist[:prefill_name]
        gist_prefill_json = ERB::Util.h(gist_prefill.to_json)

        <<~HTML
          #{style_open}
            [x-cloak] { display: none !important; }#{host_css}
            .sw-save-doc-btn {
              position: fixed; bottom: 1rem; right: 1rem; z-index: 50;
              background: var(--sw-color-primary, #1f6feb); color: #fff;
              border: none; border-radius: 999px; padding: 0.55rem 1rem;
              font-size: 0.85rem; font-weight: 600; cursor: pointer;
              box-shadow: 0 6px 16px rgba(28,25,23,0.18);
              opacity: 0.85; transition: opacity 120ms ease, transform 120ms ease;
            }
            .sw-save-doc-btn:hover { opacity: 1; transform: translateY(-1px); }
            .sw-save-doc-modal {
              position: fixed; inset: 0; z-index: 60;
              background: rgba(15, 17, 23, 0.45);
              display: flex; align-items: center; justify-content: center;
            }
            .sw-save-doc-dialog {
              background: #fff; border-radius: 8px; padding: 1.5rem;
              width: min(440px, 90vw); box-shadow: 0 20px 50px rgba(0,0,0,0.25);
              font-family: 'Source Sans 3', system-ui, sans-serif;#{dialog_css_extra}
            }
            .sw-save-doc-dialog h3 { margin: 0 0 0.5rem 0; font-size: 1.1rem; }
            .sw-save-doc-dialog p.hint {
              margin: 0 0 1rem 0; color: #6b7280; font-size: 0.85rem;
            }
            .sw-save-doc-scope {
              display: flex; gap: 1rem; margin: 0 0 0.5rem 0;
              font-size: 0.85rem; flex-wrap: wrap;
            }
            .sw-save-doc-scope label {
              display: flex; align-items: center; gap: 0.35rem; cursor: pointer;
            }
            .sw-save-doc-scope label:has(input:disabled) { cursor: not-allowed; opacity: 0.6; }
            .sw-save-doc-scope-path {
              margin: 0 0 0.75rem 0; color: #6b7280; font-size: 0.78rem;
              font-family: ui-monospace, monospace; word-break: break-all;
            }
            .sw-save-doc-scope-hint {
              color: #6b7280; font-size: 0.78rem;
            }
            .sw-save-doc-scope-reason {
              margin: 0 0 0.75rem 0; color: #b45309; font-size: 0.78rem;
            }
            .sw-save-doc-dialog input[type=text] {
              width: 100%; padding: 0.55rem 0.75rem;
              border: 1px solid #d1d5db; border-radius: 5px;
              font-size: 0.95rem; font-family: ui-monospace, monospace;
              box-sizing: border-box;
            }
            .sw-save-doc-dialog input[type=text]:focus {
              outline: 2px solid var(--sw-color-primary, #1f6feb); outline-offset: -1px;
              border-color: transparent;
            }
            .sw-save-doc-error {
              margin-top: 0.75rem; padding: 0.5rem 0.75rem;
              background: #fee2e2; color: #991b1b; border-radius: 4px;
              font-size: 0.85rem;
            }
            .sw-save-doc-success {
              margin-top: 0.75rem; padding: 0.5rem 0.75rem;
              background: #dcfce7; color: #166534; border-radius: 4px;
              font-size: 0.85rem; word-break: break-all;
            }
            .sw-save-doc-success a { color: #166534; }
            .sw-save-doc-notice {
              margin-top: 0.5rem; padding: 0.5rem 0.75rem;
              background: #fef9c3; color: #854d0e; border-radius: 4px;
              font-size: 0.85rem;
            }
            .sw-save-doc-actions {
              display: flex; justify-content: flex-end; gap: 0.5rem;
              margin-top: 1rem;
            }
            .sw-save-doc-actions button {
              padding: 0.45rem 1rem; border-radius: 5px;
              font-size: 0.9rem; cursor: pointer; border: 1px solid transparent;
            }
            .sw-save-doc-actions button:disabled { opacity: 0.5; cursor: not-allowed; }
            .sw-save-doc-cancel { background: #f3f4f6; color: #374151; border-color: #d1d5db; }
            .sw-save-doc-cancel:hover:not(:disabled) { background: #e5e7eb; }
            .sw-save-doc-save {
              background: var(--sw-color-primary, #1f6feb); color: #fff;
            }
            .sw-save-doc-save:hover:not(:disabled) { filter: brightness(1.05); }
            .sw-save-doc-save-org {
              background: #fff; color: var(--sw-color-primary, #1f6feb);
              border-color: var(--sw-color-primary, #1f6feb);
            }
            .sw-save-doc-save-org:hover:not(:disabled) { background: #eff6ff; }
            .sw-save-doc-save-gist {
              background: #fff; color: #166534; border-color: #166534;
            }
            .sw-save-doc-save-gist:hover:not(:disabled) { background: #f0fdf4; }
          #{style_close}
          <div x-data="{
            open: false,
            name: #{name_init},
            scope: '#{source_dir ? 'repo' : 'global'}',
            #{extra_alpine_data}format: 'rb',
            saving: false,
            savedPath: null,
            error: null,
            coverage: null,
            notice: null,
            gistKnown: #{gist_known_json},
            gistPrefill: #{gist_prefill_json},
            gistResult: null,
            openDialog() {
              this.error = null; this.savedPath = null; this.coverage = null; this.notice = null; this.gistResult = null;
              if (this.gistPrefill) {
                this.name = this.gistPrefill;
              } else {
                #{reset_name_js}
              }
              this.format = 'rb';
              this.open = true;
              this.$nextTick(() => this.$refs.input && this.$refs.input.select());
            },
            // The single definition of "what key does this name map to in
            // gistKnown" -- shared by currentGist() (read) and save()'s
            // record-the-new-gist step (write) so the two can never drift.
            // A drift would mean a just-saved gist gets recorded under a key
            // currentGist() can't find, the button would stay on "Create
            // gist", and the next save would mint a second gist -- exactly
            // what prefill_name exists to prevent. Strips a .rb/.org
            // extension in case the field ever carries one.
            gistKey(name) {
              return (name || '').replace(/\\.(rb|org)$/, '');
            },
            // Looks up the typed name in gistKnown -- live, as the name
            // field is edited -- so the scope hint, URL preview, and the
            // gist action button's label all stay in sync with what's
            // actually already shared under that name. Returns null when
            // nothing is known for the current name.
            currentGist() {
              return this.gistKnown[this.gistKey(this.name)] || null;
            },
            // Tiered copy for the org-coverage notice (Phase 2 design spec's
            // Save-as-Org UX section, including its 2026-08-14 copy-accuracy
            // correction: N/M must name passthrough_verbatim/passthrough_lossy
            // specifically, not a conflated total-recognized count, or a doc
            // with mostly-verbatim elements gets told MORE of it is lossy
            // than actually is). Only ever non-null after a format=org save
            // whose response included coverage; a plain .rb save leaves
            // coverage null so this stays hidden.
            orgNotice() {
              if (!this.coverage) return null;
              const { total, recognized, passthrough_verbatim, passthrough_lossy } = this.coverage;
              if (recognized === total) return null;
              let body;
              if (passthrough_verbatim > 0 && passthrough_lossy > 0) {
                body = `${passthrough_verbatim} element(s) will show as raw code in a plain org viewer (nothing lost); ${passthrough_lossy} more can't be verbatim-recovered and will be replaced with a placeholder comment instead — those specific parts won't survive the round trip.`;
              } else if (passthrough_lossy > 0) {
                body = `${passthrough_lossy} element(s) can't be verbatim-recovered and will be replaced with a placeholder comment — those specific parts won't survive the round trip.`;
              } else {
                body = `${passthrough_verbatim} element(s) will show as raw code in a plain org viewer — nothing is lost, just not styled.`;
              }
              return recognized / total < 0.5
                ? `This looks like an app, not a document — Org format won't add much here. ${body}`
                : body;
            },
            async save() {
              if (this.saving) return;
              this.saving = true; this.error = null; this.coverage = null; this.notice = null; this.gistResult = null;
              try {
                const res = await fetch('#{endpoint}', {
                  method: 'POST',
                  headers: {'Content-Type': 'application/json'},
                  body: JSON.stringify({#{extra_body_fields}name: this.name, format: this.format, scope: this.scope})
                });
                const data = await res.json();
                if (res.ok && data.ok) {
                  this.savedPath = data.path;
                  this.coverage = data.coverage || null;
                  this.notice = this.orgNotice();
                  if (data.gist_url) {
                    // A gist save's payload IS the URL, not a path -- keep
                    // the dialog open until the user dismisses it (no
                    // auto-close below) and remember it under this name so
                    // the button/hint flip to "Update gist" immediately.
                    this.gistResult = { url: data.gist_url, revisions: data.revisions };
                    this.gistKnown[this.gistKey(this.name)] = { url: data.gist_url, revisions: data.revisions };
                    // Auto-copy for zero-friction hand-off to a coworker.
                    // Clipboard access can fail (permissions, insecure
                    // context) -- that must never hide the URL, which stays
                    // visible and manually selectable in gistResult below
                    // regardless of whether the copy itself succeeded.
                    try {
                      await navigator.clipboard.writeText(data.gist_url);
                    } catch (e) {
                      // ignored -- URL is still shown and selectable below
                    }
                  } else {
                    // A tiered notice can be a full sentence or two -- the
                    // default 1.8s auto-close (tuned for a one-line success
                    // confirmation) isn't enough time to read it.
                    setTimeout(() => { this.open = false; }, this.notice ? 6000 : 1800);
                  }
                } else {
                  this.error = data.error || ('HTTP ' + res.status);
                }
              } catch (e) {
                this.error = e.message;
              } finally {
                this.saving = false;
              }
            }
          }"#{host_attr} @keydown.escape.window="open = false">
            <button class="sw-save-doc-btn" @click="openDialog()" title="#{button_title}">
              💾 Save as doc
            </button>
            <div x-show="open" x-cloak class="sw-save-doc-modal" @click.self="open = false">
              <div class="sw-save-doc-dialog" @click.stop>
                <h3>#{dialog_title}</h3>
                <p class="hint">
                  #{hint_html}
                </p>
                #{scope_html}
                <input type="text" x-model="name" x-ref="input"
                       @keydown.enter.prevent="save()"
                       :disabled="saving"
                       placeholder="my-canvas-doc">
                <div x-show="error" x-text="error" class="sw-save-doc-error"></div>
                <div x-show="savedPath && !gistResult" class="sw-save-doc-success">
                  ✓ Saved to <code x-text="savedPath"></code>
                </div>
                <div x-show="gistResult" class="sw-save-doc-success">
                  ✓ Gist saved · <span x-text="gistResult ? gistResult.revisions : ''"></span> revision(s)<br>
                  <code x-text="gistResult ? gistResult.url : ''"></code><br>
                  <a :href="gistResult ? gistResult.url : '#'" target="_blank">Open gist</a>
                  &middot;
                  <a :href="gistResult ? (gistResult.url + '/revisions') : '#'" target="_blank">Revisions</a>
                </div>
                <div x-show="notice" x-text="notice" class="sw-save-doc-notice"></div>
                <div class="sw-save-doc-actions">
                  <button class="sw-save-doc-cancel" @click="open = false" :disabled="saving">Cancel</button>
                  <button class="sw-save-doc-save-org" @click="format = 'org'; save()" :disabled="saving" x-show="scope !== 'gist'" title="Save as a plain-text .org sibling file">
                    <span x-show="!(saving && format === 'org')">Save as Org</span>
                    <span x-show="saving && format === 'org'">Saving...</span>
                  </button>
                  <button class="sw-save-doc-save" @click="format = 'rb'; save()" :disabled="saving" x-show="scope !== 'gist'">
                    <span x-show="!(saving && format === 'rb')">Save</span>
                    <span x-show="saving && format === 'rb'">Saving...</span>
                  </button>
                  <!-- No format= assignment here on purpose: scope picks the destination,
                       format picks the serialization. A gist save always sends both files
                       regardless of format, so pinning format to a third value here would
                       only risk a future 422 against a server whitelist of ['rb', 'org']. -->
                  <button class="sw-save-doc-save-gist" @click="save()" :disabled="saving" x-show="scope === 'gist'">
                    <span x-show="!saving" x-text="currentGist() ? 'Update gist' : 'Create gist'"></span>
                    <span x-show="saving">Saving...</span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        HTML
      end

      # Builds the "This repo (<basename>)" / "Global" / "Gist" radio toggle,
      # or '' when there's nothing to offer at all -- the caller-visible
      # contract is `render`'s `source_dir:`/`gist:` kwargs (see `render`'s
      # doc comment above). Renders when EITHER source_dir OR gist is
      # present; each radio is independently optional (a canvas pushed from
      # outside a git repo has no repo radio but can still offer Gist).
      def scope_toggle_html(source_dir, gist)
        return '' unless source_dir || gist

        repo_radio = if source_dir
                       repo_label = "This repo (#{ERB::Util.h(File.basename(source_dir))})"
                       %(<label><input type="radio" x-model="scope" value="repo"> #{repo_label}</label>)
                     else
                       ''
                     end

        gist_radio  = gist ? gist_radio_html(gist) : ''
        gist_reason = gist && !gist[:available] ? %(<p class="sw-save-doc-scope-reason">#{ERB::Util.h(gist[:unavailable_reason])}</p>) : ''

        <<~HTML
          <div class="sw-save-doc-scope">
            #{repo_radio}
            <label><input type="radio" x-model="scope" value="global"> Global</label>
            #{gist_radio}
          </div>
          #{source_dir ? %(<p class="sw-save-doc-scope-path" x-show="scope === 'repo'">#{ERB::Util.h(source_dir)}</p>) : ''}
          #{gist_reason}
        HTML
      end

      # The Gist `<label>` itself. Rendered disabled (never hidden -- Gloria's
      # Law: show the capability and the one thing that unblocks it) when
      # `gist[:available]` is false; its `unavailable_reason` is rendered as
      # helper text by the caller (`scope_toggle_html`, above), not here.
      def gist_radio_html(gist)
        disabled_attr = gist[:available] ? '' : ' disabled'
        <<~HTML.strip
          <label><input type="radio" x-model="scope" value="gist"#{disabled_attr}> Gist
            <span class="sw-save-doc-scope-hint" x-show="currentGist()">(already shared &middot; <span x-text="currentGist() ? currentGist().revisions : ''"></span> revision(s))</span>
          </label>
        HTML
      end
    end
  end
end
