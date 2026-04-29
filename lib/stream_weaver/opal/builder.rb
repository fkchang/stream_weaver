# frozen_string_literal: true
require "fileutils"
require "opal"
require_relative "shell"

module StreamWeaver
  module Opal
    class OpalBuilder
      def self.build(app_file, output_dir: "dist", title: nil)
        FileUtils.mkdir_p(output_dir)

        title ||= File.basename(app_file, ".rb").tr("_-", " ").split.map(&:capitalize).join(" ")

        # Opal::Builder#build expects a logical require name, not a file path.
        # Use build_str to compile source directly.
        project_root = File.join(__dir__, "../../..")
        builder = ::Opal::Builder.new(missing_require_severity: :ignore)
        builder.append_paths(project_root)

        preamble = "require 'stream_weaver/opal_entry'\n"
        app_source = preamble + File.read(app_file)
        source = builder.build_str(app_source, File.basename(app_file))

        File.write(File.join(output_dir, "app.js"), source.to_s)
        File.write(File.join(output_dir, "index.html"), OpalShell.render(title: title, app_js: "app.js"))
      end
    end
  end
end
