# frozen_string_literal: true
require "fileutils"
require "opal"
require_relative "shell"
require_relative "../css"
require_relative "../theme"

module StreamWeaver
  module Opal
    class OpalBuilder
      # Convenience entry point
      def self.build(app_file, output_dir: "dist", title: nil, theme: nil)
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
        write_theme_css
        write_index_html
      end

      private

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
        if @theme
          unless StreamWeaver::Theme::Presets.get(@theme.to_sym)
            warn "[OpalBuilder] Unknown theme preset: #{@theme}"
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
            theme_css: File.exist?(output_path("sw-theme.css")) ? "sw-theme.css" : nil,
            google_fonts_url: google_fonts_url_for_build,
            body_theme: @theme ? "sw-theme-default sw-theme-#{@theme}" : "sw-theme-default",
            dark_mode_script: StreamWeaver::Theme::AutoMode.inline_script
          ))
      end

      def google_fonts_url_for_build
        if @theme && (preset = StreamWeaver::Theme::Presets.get(@theme.to_sym))
          StreamWeaver::Theme::Presets.google_fonts_url(preset)
        else
          "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap"
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
