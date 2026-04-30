# frozen_string_literal: true
require "fileutils"
require "opal"
require_relative "shell"

module StreamWeaver
  module Opal
    class OpalBuilder
      # Convenience entry point
      def self.build(app_file, output_dir: "dist", title: nil)
        new(app_file, output_dir: output_dir, title: title).call
      end

      def initialize(app_file, output_dir: "dist", title: nil)
        @app_file   = app_file
        @output_dir = output_dir
        @title      = title || derive_title
        @lib_root   = File.expand_path(File.join(__dir__, "../.."))
        @stubs_root = File.join(__dir__, "stubs")
      end

      def call
        FileUtils.mkdir_p(@output_dir)
        write_app_js
        copy_morphdom
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

      def write_index_html
        morphdom_js = File.exist?(output_path("morphdom.min.js")) ? "morphdom.min.js" : nil
        File.write(output_path("index.html"),
          OpalShell.render(title: @title, app_js: "app.js", morphdom_js: morphdom_js))
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
        %w[set cgi json digest].each do |lib|
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
