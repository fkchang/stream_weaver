# frozen_string_literal: true

require "fileutils"
require "stream_weaver"
root = File.expand_path("../..", __dir__)
output = File.join(root, "tmp", "rendered")
stylesheet = File.read(File.join(root, "shared", "dashboard.css"), encoding: "UTF-8")
FileUtils.mkdir_p(output)

variant = ARGV.fetch(0)
raise ArgumentError, "variant must be initial or revised" unless %w[initial revised].include?(variant)

require_relative variant
app = SourceTokenWorkflow::StreamWeaverDashboard.app(stylesheet)
app.rebuild_with_state({})
html = StreamWeaver::Export::HtmlExporter.new(app).to_html
File.write(File.join(output, "streamweaver-#{variant}.html"), html)
