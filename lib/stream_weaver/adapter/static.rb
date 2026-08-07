# frozen_string_literal: true

module StreamWeaver
  module Adapter
    # Renderers for document components that carry no framework behavior.
    #
    # These emit plain markup and CSS -- no Alpine directives, no HTMX
    # attributes, no server round-trips -- so they are identical whether the
    # page is rendered by the server (AlpineJS adapter) or in the browser by
    # Opal. Both adapters include this module rather than maintaining two
    # copies.
    #
    # Including adapters must provide:
    #
    #   #inject_component_css(view, key, css)
    #     Emit +css+ into the page once per key. The mechanism differs per
    #     adapter (a <style> tag server-side, a collected stylesheet in the
    #     browser), which is why it stays out of this module.
    #
    #   #inject_sidebar_toc_assets(view)
    #     Emit the TOC stylesheet plus whatever powers scroll-spy.
    #
    #   #inject_code_highlighting(view)
    #     Make a syntax highlighter available to the markup #render_code_block
    #     emits.
    #
    #   #render_code_block_copy_button(view, component)
    #     Emit the clipboard affordance for a code block, if the adapter has
    #     one. That is behavior rather than document structure, so it is a hook
    #     instead of shared markup.
    #
    # The last three are asset/behavior seams: the *markup* is identical across
    # adapters but what backs it is not. An adapter rendering a read-only
    # document can legitimately no-op all three -- the document still renders,
    # it just won't highlight, scroll-spy, or copy.
    #
    # The view object must respond to the tag methods used below plus #plain
    # and #raw. Phlex satisfies this server-side; StreamWeaver::Opal::OpalRenderer
    # implements the same surface in the browser.
    module Static
      DOC_HEADER_CSS = <<~CSS
        /* ===========================================
           DocHeader & DocSectionHeader (sw- prefix)
           =========================================== */

        /* Suppress the StreamWeaver app shell h1 — doc_header is the title */
        body:has(.sw-doc-header) > h1 {
          display: none;
        }

        /* Tighten body top padding when doc_header takes over the page header role */
        body:has(.sw-doc-header) {
          padding-top: 3rem;
        }
        .sw-doc-header {
          border-bottom: 1px solid var(--sw-border, #e0e0e0);
          padding: 2.5rem 0 2rem;
          margin-bottom: 2.5rem;
        }

        .sw-doc-header__eyebrow {
          font-family: var(--sw-font-mono, 'SFMono-Regular', 'Cascadia Code', monospace);
          font-size: 0.69rem;
          letter-spacing: 0.12em;
          text-transform: uppercase;
          color: var(--sw-text-dim, #6b6860);
          margin-bottom: 0.75rem;
        }

        .sw-doc-header__title {
          font-family: Charter, 'Bitstream Charter', 'Sitka Text', Cambria, Georgia, serif;
          font-size: 2rem;
          font-weight: 400;
          line-height: 1.2;
          color: var(--sw-text, #141413);
          margin-bottom: 1.25rem;
        }

        .sw-doc-header__meta {
          display: flex;
          flex-wrap: wrap;
          gap: 0.5rem 1.25rem;
          font-size: 0.8125rem;
          color: var(--sw-text-dim, #6b6860);
          align-items: center;
        }

        .sw-doc-header__meta-item {
          display: inline;
        }

        .sw-doc-header__pill {
          display: inline-flex;
          align-items: center;
          font-size: 0.69rem;
          font-weight: 500;
          letter-spacing: 0.04em;
          padding: 2px 8px;
          border-radius: 3px;
        }

        .sw-doc-header__pill--default {
          background: color-mix(in oklch, var(--sw-info, #2563eb) 12%, transparent);
          color: var(--sw-info, #2563eb);
        }

        .sw-doc-header__pill--warn {
          background: color-mix(in oklch, var(--sw-warning, #d97706) 12%, transparent);
          color: color-mix(in oklch, var(--sw-warning, #d97706) 80%, #000);
        }

        .sw-doc-header__pill--good {
          background: color-mix(in oklch, var(--sw-success, #16a34a) 12%, transparent);
          color: color-mix(in oklch, var(--sw-success, #16a34a) 80%, #000);
        }

        /* Section eyebrow */
        .sw-doc-section-header {
          margin-bottom: 1rem;
        }

        .sw-doc-section-header__eyebrow {
          font-family: var(--sw-font-mono, 'SFMono-Regular', 'Cascadia Code', monospace);
          font-size: 0.66rem;
          letter-spacing: 0.1em;
          text-transform: uppercase;
          color: var(--sw-text-dim, #a09d96);
          margin-bottom: 0.625rem;
          display: flex;
          align-items: center;
          gap: 0.625rem;
        }

        .sw-doc-section-header__eyebrow::after {
          content: '';
          flex: 1;
          height: 1px;
          background: var(--sw-border, #e0e0e0);
        }

        /* Use high specificity to beat body.sw-theme-document h2 rules */
        .sw-doc-section-header > .sw-doc-section-header__title {
          font-family: Charter, 'Bitstream Charter', 'Sitka Text', Cambria, Georgia, serif;
          font-size: 1.4rem;
          font-weight: 400;
          line-height: 1.25;
          color: var(--sw-text, #141413);
          margin: 0;
          padding-bottom: 0;
          border-bottom: none;
        }
      CSS

      def render_text(view, content, tone = nil, options = {})
        if tone
          inject_text_tone_css(view)
          css_classes = ["sw-text", "sw-text--#{tone}"]
          css_classes << options[:class] if options[:class]
          attrs = { class: css_classes.join(" ") }
          attrs[:style] = options[:style] if options[:style]
          view.p(**attrs) { content }
        else
          view.p { content }
        end
      end

      def render_callout(view, component, state)
        inject_callout_css(view)

        view.div(class: "sw-callout #{component.variant_class}", role: "note") do
          view.div(class: "sw-callout__icon", "aria-hidden" => "true") do
            view.plain(component.icon)
          end
          view.div(class: "sw-callout__body") do
            if component.title
              view.div(class: "sw-callout__title") { component.title }
            end
            view.div(class: "sw-callout__content") do
              component.children.each { |child| child.render(view, state) }
            end
          end
        end
      end

      def render_comparison(view, component, state)
        inject_comparison_css(view)

        view.div(class: "sw-comparison") do
          # Before panel
          view.div(class: "sw-comparison__panel sw-comparison__panel--before") do
            view.div(class: "sw-comparison__label") { component.before_label }
            view.div(class: "sw-comparison__content") do
              component.before_children.each { |child| child.render(view, state) }
            end
          end
          # After panel
          view.div(class: "sw-comparison__panel sw-comparison__panel--after") do
            view.div(class: "sw-comparison__label") { component.after_label }
            view.div(class: "sw-comparison__content") do
              component.after_children.each { |child| child.render(view, state) }
            end
          end
        end
      end

      def render_doc_header(view, component, state)
        inject_doc_header_css(view)

        view.header(class: "sw-doc-header") do
          if component.eyebrow
            view.div(class: "sw-doc-header__eyebrow") { view.plain(component.eyebrow) }
          end
          view.h1(class: "sw-doc-header__title") { view.plain(component.title) }
          unless component.pills.empty?
            view.div(class: "sw-doc-header__meta") do
              component.pills.each do |pill|
                if pill.is_a?(Hash)
                  variant = pill[:variant] || :default
                  view.span(class: "sw-doc-header__pill sw-doc-header__pill--#{variant}") do
                    view.plain(pill[:text].to_s)
                  end
                else
                  view.span(class: "sw-doc-header__meta-item") { view.plain(pill.to_s) }
                end
              end
            end
          end
        end
      end

      def render_doc_section_header(view, component, state)
        inject_doc_header_css(view)

        attrs = { class: "sw-doc-section-header" }
        attrs[:id] = component.anchor_id if component.anchor_id
        view.div(**attrs) do
          view.div(class: "sw-doc-section-header__eyebrow") { view.plain(component.number) }
          view.h2(class: "sw-doc-section-header__title") { view.plain(component.title) }
        end
      end

      def inject_callout_css(view)
        inject_component_css(view, :callout, callout_css)
      end

      def inject_comparison_css(view)
        inject_component_css(view, :comparison, comparison_css)
      end

      def inject_text_tone_css(view)
        inject_component_css(view, :text_tone, text_tone_css)
      end

      def inject_doc_header_css(view)
        inject_component_css(view, :doc_header, doc_header_css)
      end

      def callout_css
        <<~CSS
          /* ===========================================
             Callout Styles (sw- prefix, T11)
             =========================================== */
          .sw-callout {
            display: flex;
            gap: 0.75rem;
            padding: var(--sw-callout-padding, 1rem 1.25rem);
            border-radius: var(--sw-radius-md, 6px);
            border-left: 4px solid var(--sw-info, #2563eb);
            background: color-mix(in oklch, var(--sw-info) 6%, var(--sw-surface, #ffffff));
            margin: 0.75rem 0;
          }

          .sw-callout__icon {
            flex-shrink: 0;
            font-size: 1.25rem;
            line-height: 1.4;
          }

          .sw-callout__body {
            flex: 1;
            min-width: 0;
          }

          .sw-callout__title {
            font-weight: 700;
            font-size: 0.9375rem;
            margin-bottom: 0.25rem;
            color: var(--sw-text, #111111);
          }

          .sw-callout__content {
            font-size: 0.875rem;
            color: var(--sw-text, #111111);
            line-height: 1.6;
          }

          /* Variant colors */
          .sw-callout--info {
            border-left-color: var(--sw-info, #2563eb);
            background: color-mix(in oklch, var(--sw-info) 6%, var(--sw-surface, #ffffff));
          }

          .sw-callout--warning {
            border-left-color: var(--sw-warning, #d97706);
            background: color-mix(in oklch, var(--sw-warning) 6%, var(--sw-surface, #ffffff));
          }

          .sw-callout--success {
            border-left-color: var(--sw-success, #16a34a);
            background: color-mix(in oklch, var(--sw-success) 6%, var(--sw-surface, #ffffff));
          }

          .sw-callout--error {
            border-left-color: var(--sw-error, #dc2626);
            background: color-mix(in oklch, var(--sw-error) 6%, var(--sw-surface, #ffffff));
          }

          .sw-callout--tip {
            border-left-color: #7c3aed;
            background: color-mix(in oklch, #7c3aed 6%, var(--sw-surface, #ffffff));
          }

          .sw-callout--decision {
            border-left-color: #b45309;
            background: color-mix(in oklch, #b45309 6%, var(--sw-surface, #ffffff));
          }

          .sw-callout--risk {
            border-left-color: #dc2626;
            background: color-mix(in oklch, #dc2626 10%, var(--sw-surface, #ffffff));
          }

          /* Dark mode adjustments */
          html.dark .sw-callout {
            background: color-mix(in oklch, var(--sw-info) 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--info {
            background: color-mix(in oklch, var(--sw-info) 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--warning {
            background: color-mix(in oklch, var(--sw-warning) 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--success {
            background: color-mix(in oklch, var(--sw-success) 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--error {
            background: color-mix(in oklch, var(--sw-error) 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--tip {
            background: color-mix(in oklch, #a78bfa 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--decision {
            background: color-mix(in oklch, #fbbf24 8%, var(--sw-surface, oklch(0.205 0 0)));
          }
          html.dark .sw-callout--risk {
            background: color-mix(in oklch, #f87171 10%, var(--sw-surface, oklch(0.205 0 0)));
          }
        CSS
      end

      def comparison_css
        <<~CSS
          /* ===========================================
             Comparison Styles (sw- prefix, T11)
             =========================================== */
          .sw-comparison {
            display: flex;
            gap: 1rem;
            margin: 0.75rem 0;
          }

          .sw-comparison__panel {
            flex: 1;
            min-width: 0;
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            background: var(--sw-surface, #ffffff);
            overflow: hidden;
          }

          .sw-comparison__label {
            padding: 0.5rem 1rem;
            font-size: 0.75rem;
            font-weight: 700;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            color: var(--sw-text-dim, #444444);
            background: var(--sw-surface-elevated, #f3f3f3);
            border-bottom: 1px solid var(--sw-border, #e0e0e0);
          }

          .sw-comparison__content {
            padding: 1rem;
          }

          /* Before panel: subtle red/warm tint */
          .sw-comparison__panel--before {
            border-top: 3px solid var(--sw-error, #dc2626);
          }

          /* After panel: subtle green/cool tint */
          .sw-comparison__panel--after {
            border-top: 3px solid var(--sw-success, #16a34a);
          }

          /* Responsive: stack vertically on narrow viewports */
          @media (max-width: 767px) {
            .sw-comparison {
              flex-direction: column;
            }
          }
        CSS
      end

      def text_tone_css
        <<~CSS
          /* ===========================================
             Text Tone Variants (sw- prefix, FAC-P2.2)
             =========================================== */
          .sw-text--muted {
            color: var(--sw-color-text-muted, #6b7280);
          }

          .sw-text--caption {
            font-size: var(--sw-font-size-sm, 0.875rem);
            color: var(--sw-color-text-muted, #6b7280);
          }

          .sw-text--error {
            color: var(--sw-error, #dc2626);
          }

          .sw-text--success {
            color: var(--sw-success, #16a34a);
          }
        CSS
      end

      def doc_header_css
        DOC_HEADER_CSS
      end

      def render_sidebar_toc(view, component, state)
        inject_sidebar_toc_assets(view)

        view.nav(class: "sw-sidebar-toc", "aria-label" => "Table of contents") do
          view.div(class: "sw-sidebar-toc__nav") do
            component.sections.each do |section|
              view.a(
                class: "sw-sidebar-toc__link",
                href: "##{section[:id]}",
                "data-sw-toc-target" => section[:id]
              ) { section[:label] }
            end
          end
        end
      end

      def render_code_block(view, component, state)
        inject_code_highlighting(view)

        view.div(class: "sw-code-block") do
          # Header bar (optional) -- file path label and/or copy affordance
          if component.file || component.copy
            view.div(class: "sw-code-block__header") do
              if component.file
                view.span(class: "sw-code-block__file") { component.file }
              end
              render_code_block_copy_button(view, component) if component.copy
            end
          end

          # Code container
          scroll_style = component.scroll ? "overflow: auto; max-height: 500px;" : ""
          view.div(class: "sw-code-block__body", style: scroll_style) do
            view.pre(class: "sw-code-block__pre") do
              view.code(class: component.language_class) do
                view.plain(component.display_code)
              end
            end
          end

          # Truncation indicator
          if component.truncated?
            view.div(class: "sw-code-block__truncated") do
              view.plain("... #{component.total_lines - component.truncate} more lines")
            end
          end
        end
      end

      def sidebar_toc_css
        <<~CSS
          /* ===========================================
             SidebarToc Styles (sw- prefix, T11)
             =========================================== */
          .sw-sidebar-toc {
            position: sticky;
            top: 1rem;
            z-index: 10;
          }

          /* Undo the base overflow-x:auto on #app-container (views.rb's
             `body[class*="sw-layout-"] > #app-container`) -- a non-visible
             overflow-x computes overflow-y to auto, making the container a
             scroll container and killing position:sticky for the TOC. Must
             out-specify that selector (#app-container:has(...) alone is one
             type selector short, see spec/components/sidebar_toc_spec.rb)
             and must stay outside @media: the mobile top nav is sticky too.
             Code/diff/board components scroll locally (e.g.
             .sw-code-block__body), so this doesn't affect them; a wide
             *table* with no scrollable:/sticky_header: option has no local
             overflow wrapper and will now overflow to the page-level
             `html { overflow-x: auto }` scroller instead -- accepted, since
             a stuck TOC beats a nested table scrollbar. */
          body[class*="sw-layout-"] > #app-container:has(> .sw-sidebar-toc) {
            overflow: visible;
          }

          .sw-sidebar-toc__nav {
            counter-reset: sw-toc-counter;
          }

          /* Desktop: vertical sidebar */
          @media (min-width: 1000px) {
            .sw-sidebar-toc {
              grid-column: 1;
              /* Span a large number of implicit rows so the sidebar's grid
                 area covers the full content height (unknown ahead of time,
                 since content renders as flat siblings with no wrapper) —
                 without this, position:sticky only holds within the
                 sidebar's own (short) auto row. */
              grid-row: 1 / 9999;
              align-self: start;
              top: 2rem;
            }

            .sw-sidebar-toc__nav {
              display: flex;
              flex-direction: column;
              gap: 0.25rem;
              max-height: calc(100vh - 4rem);
              overflow-y: auto;
            }
          }

          /* Mobile: horizontal scrollable bar */
          @media (max-width: 999px) {
            .sw-sidebar-toc {
              top: 0;
              background: var(--sw-surface, #ffffff);
              border-bottom: 1px solid var(--sw-border, #e0e0e0);
              padding: 0.5rem 0;
              margin: 0 -1rem 1rem -1rem;
              width: calc(100% + 2rem);
            }

            .sw-sidebar-toc__nav {
              display: flex;
              flex-direction: row;
              gap: 0.25rem;
              overflow-x: auto;
              -webkit-overflow-scrolling: touch;
              scrollbar-width: none;
              padding: 0 1rem;
            }

            .sw-sidebar-toc__nav::-webkit-scrollbar {
              display: none;
            }

            .sw-sidebar-toc__link {
              white-space: nowrap;
              flex-shrink: 0;
            }
          }

          .sw-sidebar-toc__link {
            display: flex;
            align-items: baseline;
            gap: 0.5rem;
            counter-increment: sw-toc-counter;
            padding: 0.375rem 0.75rem;
            font-size: 0.8125rem;
            color: var(--sw-text-dim, #444444);
            text-decoration: none;
            border-radius: var(--sw-radius-sm, 4px);
            border-left: 2px solid transparent;
            transition: color 150ms ease-out, background 150ms ease-out, border-color 150ms ease-out;
          }

          .sw-sidebar-toc__link::before {
            content: counter(sw-toc-counter, decimal-leading-zero);
            flex-shrink: 0;
            font-family: var(--sw-font-mono, 'SFMono-Regular', 'Cascadia Code', monospace);
            font-size: 0.625rem;
            color: var(--sw-text-dim, #6b7280);
          }

          .sw-sidebar-toc__link:hover {
            color: var(--sw-text, #111111);
            background: var(--sw-surface-elevated, #f3f3f3);
          }

          .sw-sidebar-toc__link.sw-is-active {
            color: var(--sw-accent, #0d9488);
            border-left-color: var(--sw-accent, #0d9488);
            font-weight: 600;
            background: color-mix(in oklch, var(--sw-accent) 6%, transparent);
          }

          @media (max-width: 999px) {
            .sw-sidebar-toc__link {
              border-left: none;
              border-bottom: 2px solid transparent;
            }

            .sw-sidebar-toc__link.sw-is-active {
              border-left-color: transparent;
              border-bottom-color: var(--sw-accent, #0d9488);
            }
          }

          /* ── Document layout fix ──
             When sidebar_toc is present:
             - Expand the body to give the sidebar room
             - Remove the card chrome from #app-container
             - Remove top padding (hidden h1 leaves a gap) */
          @media (min-width: 1000px) {
            /* All the :has() checks below are scoped to a DIRECT child
               sidebar_toc/doc_header (the flat prd_dsl.rb-style page
               pattern: sidebar_toc and doc content as siblings directly
               inside #app-container). Without the ">" combinator, :has()
               matches sidebar_toc/doc_header at ANY depth -- so a page
               that nests sidebar_toc deep inside an app_shell (its own
               main/columns/column layout) would still hijack #app-container
               into this grid. Since app_shell is then #app-container's
               ONLY child, CSS Grid auto-placement drops it into just the
               first (toc-width) column and leaves the second column empty
               -- collapsing the entire app_shell to ~220px wide. */
            body:has(> #app-container > .sw-sidebar-toc) {
              max-width: 1200px;
            }

            body:has(> #app-container > .sw-doc-header) > h1 + #app-container,
            #app-container:has(> .sw-sidebar-toc) {
              padding-top: 0;
              box-shadow: none;
              border: none;
              background: transparent;
              border-radius: 0;
            }

            /* Sidebar + content as a CSS grid (replaces the old
               float + negative-margin hack, which let the sidebar scroll
               away instead of staying sticky). The overflow:visible fix
               that makes position:sticky work lives on the
               `body[class*="sw-layout-"] > #app-container:has(> .sw-sidebar-toc)`
               rule above, not here -- it has to apply below 1000px too,
               for the mobile top nav. */
            #app-container:has(> .sw-sidebar-toc) {
              --sw-toc-width: 220px;
              --sw-toc-gap: 2rem;
              display: grid;
              grid-template-columns: var(--sw-toc-width) minmax(0, 1fr);
              column-gap: var(--sw-toc-gap);
            }

            /* doc_header stays a normal column-2 grid item (never claims
               column 1) so it can't block the sidebar's row-span below —
               it bleeds visually full-width via negative margin instead. */
            #app-container:has(> .sw-sidebar-toc) > .sw-doc-header {
              margin-left: calc(-1 * (var(--sw-toc-width) + var(--sw-toc-gap)));
              padding-left: calc(var(--sw-toc-width) + var(--sw-toc-gap));
            }
          }
        CSS
      end

      def render_diff_block(view, component, state)
        inject_code_highlighting(view)
        inject_diff_block_css(view)

        parsed = component.parsed_lines
        view.div(class: "sw-diff-block") do
          view.pre(class: "sw-diff-block__pre") do
            parsed.each do |dl|
              if dl.type == :hunk_header
                view.span(class: "sw-diff-block__hunk-header") { view.plain(dl.content) }
                next
              end

              line_class = case dl.type
                           when :removed then "sw-diff-block__line sw-diff-block__line--removed"
                           when :added   then "sw-diff-block__line sw-diff-block__line--added"
                           else               "sw-diff-block__line sw-diff-block__line--context"
                           end

              view.span(class: line_class) do
                view.span(class: "sw-diff-block__gutter") do
                  old_str = dl.old_num ? dl.old_num.to_s : ""
                  new_str = dl.new_num ? dl.new_num.to_s : ""
                  view.span(class: "sw-diff-block__gutter-old") { view.plain(old_str) }
                  view.span(class: "sw-diff-block__gutter-new") { view.plain(new_str) }
                end
                view.span(class: "sw-diff-block__prefix") { view.plain(dl.prefix) }
                view.code(class: component.language_class) { view.plain(dl.content) }
              end
            end
          end
        end
      end

      def inject_diff_block_css(view)
        inject_component_css(view, :diff_block, diff_block_css)
      end

      def diff_block_css
        <<~CSS
          /* -- DiffBlock -- */
          .sw-diff-block {
            border: 1px solid var(--sw-border, #e0e0e0);
            border-radius: var(--sw-radius-md, 6px);
            overflow: hidden;
            margin: 0.75rem 0;
            background: var(--sw-surface, #1d1f21);
            color: #c5c8c6;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 0.875rem;
          }

          .sw-diff-block__pre {
            margin: 0;
            padding: 0.5rem 0;
            background: transparent;
            white-space: pre;
            overflow-x: auto;
          }

          .sw-diff-block__hunk-header {
            display: block;
            padding: 0.15rem 0.75rem;
            color: var(--sw-text-dim, #6b7280);
            background: color-mix(in oklch, #4b5563 15%, transparent);
            font-style: italic;
            white-space: pre;
          }

          .sw-diff-block__line {
            display: flex;
            align-items: baseline;
            line-height: 1.5em;
            min-height: 1.5em;
            padding-right: 0.75rem;
          }

          .sw-diff-block__line--removed {
            background: color-mix(in oklch, #dc2626 14%, transparent);
          }

          .sw-diff-block__line--added {
            background: color-mix(in oklch, #16a34a 14%, transparent);
          }

          .sw-diff-block__gutter {
            display: inline-flex;
            gap: 0;
            user-select: none;
            color: var(--sw-text-dim, #6b7280);
            flex-shrink: 0;
          }

          .sw-diff-block__gutter-old,
          .sw-diff-block__gutter-new {
            display: inline-block;
            width: 2.5rem;
            padding: 0 0.5rem;
            text-align: right;
          }

          .sw-diff-block__prefix {
            display: inline-block;
            width: 1.2rem;
            text-align: center;
            flex-shrink: 0;
            user-select: none;
            color: var(--sw-text-dim, #6b7280);
          }

          .sw-diff-block__line--removed .sw-diff-block__prefix {
            color: #f87171;
          }

          .sw-diff-block__line--added .sw-diff-block__prefix {
            color: #4ade80;
          }

          .sw-diff-block__line code {
            background: transparent;
            color: inherit;
            padding: 0;
            font-size: inherit;
            font-family: inherit;
            white-space: pre;
            flex: 1;
          }
        CSS
      end
    end
  end
end
