# Usage: streamweaver canvas-push <session> < examples/components/code_preview_demo.rb
# Or:    streamweaver panel code-preview-demo && streamweaver canvas-push code-preview-demo < examples/components/code_preview_demo.rb

header2 "Code Preview"

code_preview <<~RUBY, title: "One source, one rendered result", file: "examples/components/code_preview_demo.rb"
  header3 "Build health"
  badge "Passing", variant: :success
  text "3 checks completed"
RUBY

code_preview <<~RUBY, title: "Stacked layout", layout: :stacked
  callout(variant: :tip, title: "Preview first") do
    text "The rendered result appears above the source in stacked mode."
  end
RUBY
