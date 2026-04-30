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

        # Build the Opal runtime + StreamWeaver + user app into a single JS bundle.
        # lib_root = lib/ directory; stubs_root = lib/stream_weaver/opal/stubs/
        # Stubs must be added first so they shadow any Opal stdlib for missing modules.
        lib_root   = File.expand_path(File.join(__dir__, "../.."))
        stubs_root = File.join(__dir__, "stubs")
        builder = ::Opal::Builder.new(missing_require_severity: :ignore)
        builder.append_paths(stubs_root)  # stubs shadow Opal stdlib for digest etc.
        builder.append_paths(lib_root)

        # Step 1: Include the Opal core runtime (sets up the global Opal object)
        builder.build("opal")

        # Step 2: Include Opal stdlib modules required by StreamWeaver.
        # digest comes from our stubs/ directory (not in Opal stdlib).
        ["set", "cgi", "json", "digest"].each { |lib| builder.build(lib) rescue nil }

        # Step 3: Compile StreamWeaver's browser-only require tree.
        # This registers all StreamWeaver modules so they're available when the
        # user app's `require 'stream_weaver/opal_entry'` executes at runtime.
        builder.build("stream_weaver/opal_entry")

        # Step 3: Compile the user app.
        # Strip require_relative and require 'stream_weaver' lines — everything is
        # already bundled by the opal_entry step above. Also strip the `App.run!`
        # guard since there's no ARGV in the browser.
        app_source = File.read(app_file)
          .gsub(/^\s*require_relative\s+['"][^'"]+['"]\s*$/, "")
          .gsub(/^\s*require\s+['"]stream_weaver['"]\s*$/, "")
        source = builder.build_str(app_source, File.basename(app_file))

        # Copy morphdom from our stubs so the bundle works without CDN access
        morphdom_src = File.join(stubs_root, "morphdom.min.js")
        morphdom_dest = File.join(output_dir, "morphdom.min.js")
        FileUtils.cp(morphdom_src, morphdom_dest) if File.exist?(morphdom_src)
        morphdom_js = File.exist?(morphdom_dest) ? "morphdom.min.js" : nil

        File.write(File.join(output_dir, "app.js"), source.to_s)
        File.write(File.join(output_dir, "index.html"), OpalShell.render(title: title, app_js: "app.js", morphdom_js: morphdom_js))
      end
    end
  end
end
