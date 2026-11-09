# frozen_string_literal: true
require "fileutils"
require_relative "shell"
require_relative "../css"
require_relative "../theme"
require_relative "../page_shell"

module StreamWeaver
  module Opal
    class OpalBuilder
      # opal is the heavyweight compiler behind `streamweaver opal-build` --
      # not a runtime dependency of the gem (see stream_weaver.gemspec), so a
      # doc-shelf-only install must never be forced to have it. Load it here,
      # on first actual use, instead of at file-load time.
      def self.require_opal!
        require "opal"
      rescue LoadError
        raise LoadError, "Opal features need the opal gem: gem install opal"
      end

      # Convenience entry point
      def self.build(app_file, output_dir: "dist", title: nil, theme: nil)
        require_opal!
        new(app_file, output_dir: output_dir, title: title, theme: theme).call
      end

      def initialize(app_file, output_dir: "dist", title: nil, theme: nil)
        @app_file   = app_file
        @output_dir = output_dir
        @title      = title || derive_title
        @theme      = theme
        @lib_root   = File.expand_path(File.join(__dir__, "../.."))
        @stubs_root = File.join(__dir__, "stubs")
      end

      def call
        FileUtils.mkdir_p(@output_dir)
        write_app_js
        copy_morphdom
        copy_marked
        copy_browser_assets
        write_theme_css
        write_index_html
      end

      private

      # Assets committed under opal/stubs, plus mermaid from the gitignored
      # vendor dir (see bin/vendor_browser_assets -- it is too large to commit).
      # Anything missing falls back to its CDN in OpalShell, which keeps builds
      # working for web deployment; only offline and browser-extension hosts
      # actually require the local copies.
      #
      # sw-mermaid-zoom.js is different from the rest: it is StreamWeaver's own
      # code, not a third-party library, so it has no CDN to fall back to and
      # is always committed (unlike mermaid.min.js itself). It is copied
      # unconditionally -- since Adapter::Static#render_mermaid (shared by both
      # adapters) always writes the mermaid source into a data attribute rather
      # than element text, this engine is the only thing that can read it. A
      # build missing it would render an empty box, not a diagram
      # (stream_weaver-mermaid-extension).
      def copy_browser_assets
        {
          "prism.min.js"           => File.join(@stubs_root, "prism.min.js"),
          "prism-tomorrow.min.css" => File.join(@stubs_root, "prism-tomorrow.min.css"),
          "diff.min.js"            => File.join(@stubs_root, "diff.min.js"),
          "mermaid.min.js"         => mermaid_source_path,
          "sw-mermaid-zoom.js"     => File.join(@lib_root, "stream_weaver", "assets", "js", "sw-mermaid-zoom.js"),
          "sw-replay.js"           => File.join(@lib_root, "stream_weaver", "assets", "js", "sw-replay.js")
        }.each do |name, src|
          next unless src && File.exist?(src)

          FileUtils.cp(src, output_path(name))
        end

        return if mermaid_source_path && File.exist?(mermaid_source_path)

        warn "[OpalBuilder] mermaid.min.js not vendored -- falling back to CDN. " \
             "Run bin/vendor_browser_assets for an offline build."
      end

      def mermaid_source_path
        @mermaid_source_path ||= File.join(@lib_root, "..", "vendor", "js", "mermaid.min.js")
      end

      def local_asset(name)
        File.exist?(output_path(name)) ? name : nil
      end

      def write_app_js
        File.write(output_path("app.js"), compile.to_s)
      end

      def copy_morphdom
        src = File.join(@stubs_root, "morphdom.min.js")
        FileUtils.cp(src, output_path("morphdom.min.js")) if File.exist?(src)
      end

      def copy_marked
        src = File.join(@stubs_root, "marked.umd.js")
        FileUtils.cp(src, output_path("marked.umd.js")) if File.exist?(src)
      end

      def write_theme_css
        css = StreamWeaver::CSS.full_stylesheet
        css += "\n" + StreamWeaver::Theme.visual_skills_css
        css += "\n" + StreamWeaver::CSS.animation_css
        # The css macro CSS of every registered component class: layered
        # where the class asked for it, user CSS unlayered (spec/css_layer_spec.rb).
        unless components.framework_css.empty?
          css += "\n" + StreamWeaver::CSS.layer_wrap(components.framework_css.join("\n"))
        end
        css += "\n" + components.user_css.join("\n") unless components.user_css.empty?
        if @theme
          # --theme names a registered theme (its fonts and stylesheets reach
          # the page through #page) or a Theme::Presets entry (its CSS lands
          # here); warn only when it is neither.
          unless StreamWeaver::Theme::Presets.get(@theme.to_sym) || StreamWeaver.theme_exists?(@theme)
            warn "[OpalBuilder] Unknown theme: #{@theme} (neither a registered theme nor a preset)"
          end
          css += "\n" + StreamWeaver::Theme::Presets.generate_preset_css(@theme.to_sym)
        end
        File.write(output_path("sw-theme.css"), css)
      end

      def write_index_html
        morphdom_js = File.exist?(output_path("morphdom.min.js")) ? "morphdom.min.js" : nil
        marked_js   = File.exist?(output_path("marked.umd.js"))   ? "marked.umd.js"   : nil
        File.write(output_path("index.html"),
          OpalShell.render(
            title: @title,
            app_js: "app.js",
            morphdom_js: morphdom_js,
            marked_js: marked_js,
            prism_js: local_asset("prism.min.js"),
            prism_css: local_asset("prism-tomorrow.min.css"),
            diff_js: local_asset("diff.min.js"),
            mermaid_js: local_asset("mermaid.min.js"),
            mermaid_zoom_js: local_asset("sw-mermaid-zoom.js"),
            replay_js: local_asset("sw-replay.js"),
            theme_css: File.exist?(output_path("sw-theme.css")) ? "sw-theme.css" : nil,
            google_fonts_url: google_fonts_url_for_build,
            page_links_html: page_links_html,
            body_theme: page.body_class,
            dark_mode_script: StreamWeaver::Theme::AutoMode.inline_script
          ))
      end

      # The build-time page. An Opal build has no App (it receives a file name)
      # and no layout class, and reads --theme as a registered theme's name
      # (or a preset's). Its stylesheet scopes the base variables to
      # body.sw-theme-default, so that class always comes first: it is
      # prepended here rather than in PageShell.resolve, because no other
      # host needs it. With no component tree either, it carries the files
      # and fonts of every registered component class.
      def page
        @page ||= StreamWeaver::PageShell::Page.new(
          theme: @theme, layout: nil, assets: StreamWeaver::Assets.of(body_classes: %w[sw-theme-default])
        ) + StreamWeaver::PageShell.resolve(nil, theme: @theme, layout: nil).assets +
          StreamWeaver::Assets.of(stylesheets: components.stylesheets, scripts: components.scripts,
                                             fonts: components.fonts)
      end

      def components
        @components ||= StreamWeaver::ComponentAssets.every_class_assets
      end

      # Local files are copied into the build (Delivery::Copied).
      def page_links_html
        head = StreamWeaver::PageShell.head(page, StreamWeaver::Delivery::Copied.new(@output_dir))
        [head.stylesheets, head.fonts, head.scripts].reject(&:empty?).join("\n")
      end

      def google_fonts_url_for_build
        if @theme && (preset = StreamWeaver::Theme::Presets.get(@theme.to_sym))
          StreamWeaver::Theme::Presets.google_fonts_url(preset)
        else
          StreamWeaver::Fonts::BASE_HREF
        end
      end

      def compile
        builder = build_opal_bundle
        builder.build_str(stripped_source, File.basename(@app_file))
      end

      def build_opal_bundle
        ::Opal::Builder.new(missing_require_severity: :ignore).tap do |b|
          b.append_paths(@stubs_root)
          b.append_paths(@lib_root)
          b.build("opal")
          # Must come immediately after "opal" (which defines Opal.regexp) --
          # see regexp_anchor_patch.rb's own header comment for what bug
          # this fixes and why the position matters (every compiled file
          # captures its own local reference to the function it patches, at
          # load time). This build (`streamweaver opal-build`, the AOT
          # per-file compile path) doesn't currently hit the bug this
          # patches -- nothing in its output builds a runtime-interpolated
          # \A/\z-anchored regex today -- but bin/build_extension's bundle
          # does, and keeping both Opal builders in sync means the fix
          # doesn't silently stop applying the moment that changes.
          b.build("stream_weaver/opal/regexp_anchor_patch")
          build_stdlib(b)
          b.build("stream_weaver/opal_entry")
        end
      end

      def build_stdlib(builder)
        %w[set cgi json digest thread].each do |lib|
          builder.build(lib)
        rescue => e
          warn "[OpalBuilder] Could not build stdlib '#{lib}': #{e.message}"
        end
      end

      def stripped_source
        File.read(@app_file)
          .gsub(/^\s*require_relative\s+['"][^'"]+['"]\s*$/, "")
          .gsub(/^\s*require\s+['"]stream_weaver['"]\s*$/, "")
      end

      def output_path(filename)
        File.join(@output_dir, filename)
      end

      def derive_title
        File.basename(@app_file, ".rb").tr("_-", " ").split.map(&:capitalize).join(" ")
      end
    end
  end
end
