#!/usr/bin/env ruby
# frozen_string_literal: true

# StreamWeaver Examples Browser
# Browse, view, and run StreamWeaver examples with syntax highlighting.
#
# Run with: ruby examples/advanced/examples_browser.rb

require_relative "../../lib/stream_weaver"

# Track spawned server PIDs for cleanup
SPAWNED_PIDS = []

at_exit do
  SPAWNED_PIDS.each do |pid|
    Process.kill('TERM', pid) rescue nil
  end
end

# Helper module for example discovery
module ExamplesBrowser
  EXAMPLES_ROOT = File.expand_path("../../", __FILE__)

  # Skip the browser itself to avoid inception
  SKIP_FILES = ["examples_browser.rb"].freeze

  # Directory display order and descriptions
  DIRECTORIES = {
    basic: { label: "Basic", description: "Getting started examples" },
    agentic: { label: "Agentic", description: "AI agent workflows" },
    components: { label: "Components", description: "Individual component demos" },
    layout: { label: "Layout", description: "Layout and navigation" },
    styling: { label: "Styling", description: "Themes and feedback" },
    advanced: { label: "Advanced", description: "Full applications" }
  }.freeze

  def discover_examples
    DIRECTORIES.map do |dir_key, info|
      dir_path = File.join(EXAMPLES_ROOT, dir_key.to_s)
      next unless File.directory?(dir_path)

      files = Dir.glob(File.join(dir_path, "*.rb"))
        .map { |f| File.basename(f) }
        .reject { |f| SKIP_FILES.include?(f) }
        .sort

      {
        key: dir_key,
        label: info[:label],
        description: info[:description],
        path: dir_path,
        files: files
      }
    end.compact
  end

  def read_file(dir_key, filename)
    path = File.join(EXAMPLES_ROOT, dir_key.to_s, filename)
    return "" unless File.exist?(path)
    File.read(path)
  end

  def file_path(dir_key, filename)
    File.join(EXAMPLES_ROOT, dir_key.to_s, filename)
  end

  def check_syntax(code)
    require 'open3'
    # Write to temp file and check syntax
    temp_file = "/tmp/sw_syntax_check_#{Process.pid}.rb"
    File.write(temp_file, code)

    stdout, stderr, status = Open3.capture3("ruby", "-c", temp_file)
    File.delete(temp_file) rescue nil

    if status.success?
      { ok: true, message: "Syntax OK" }
    else
      # Parse error message to make it more readable
      error = stderr.gsub(temp_file, "example.rb")
      { ok: false, message: error.strip }
    end
  end

  def run_example(file_path)
    # Kill any previous spawned servers
    SPAWNED_PIDS.each { |pid| Process.kill('TERM', pid) rescue nil }
    SPAWNED_PIDS.clear

    # Spawn new process
    pid = spawn("ruby", file_path, [:out, :err] => "/dev/null")
    SPAWNED_PIDS << pid
    pid
  end

  def kill_servers
    count = SPAWNED_PIDS.length
    SPAWNED_PIDS.each { |pid| Process.kill('TERM', pid) rescue nil }
    SPAWNED_PIDS.clear
    count
  end
end

# CodeMirror 5 CDN URLs
CODEMIRROR_CSS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css"
CODEMIRROR_JS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"
CODEMIRROR_RUBY = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/ruby/ruby.min.js"

app = StreamWeaver::App.new(
  "StreamWeaver Examples",
  layout: :wide,
  theme: :default,
  stylesheets: [CODEMIRROR_CSS],
  scripts: [CODEMIRROR_JS, CODEMIRROR_RUBY],
  components: [ExamplesBrowser]
) do
  # Initialize state
  state[:examples] ||= discover_examples
  state[:selected_dir] ||= :basic
  state[:selected_file] ||= state[:examples].first&.dig(:files)&.first
  state[:code_content] ||= ""
  state[:error_modal_open] ||= false
  state[:error_message] ||= ""
  state[:last_run_file] ||= nil

  # Load file content when selection changes
  if state[:selected_file] && state[:code_content].empty?
    state[:code_content] = read_file(state[:selected_dir], state[:selected_file])
  end

  # Header
  hstack justify: :between, align: :center do
    header1 "StreamWeaver Examples"
    hstack spacing: :sm do
      if SPAWNED_PIDS.any?
        button "Kill #{SPAWNED_PIDS.length} Server(s)", style: :secondary do |s|
          kill_servers
          s[:last_run_file] = nil
        end
      end
    end
  end

  # Main layout: sidebar + content
  columns widths: ['220px', '1fr'] do
    # Sidebar
    column do
      card do
        card_header "Examples"
        card_body do
          vstack spacing: :xs do
            state[:examples].each do |dir|
              # Directory header (collapsible)
              collapsible "#{dir[:label]} (#{dir[:files].length})", expanded: (dir[:key] == state[:selected_dir]) do
                vstack spacing: :xs do
                  dir[:files].each do |filename|
                    is_selected = state[:selected_dir] == dir[:key] && state[:selected_file] == filename
                    style = is_selected ? :primary : :secondary

                    button filename.sub('.rb', ''), style: style do |s|
                      s[:selected_dir] = dir[:key]
                      s[:selected_file] = filename
                      s[:code_content] = read_file(dir[:key], filename)
                      s[:last_run_file] = nil
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # Main content
    column do
      if state[:selected_file]
        card do
          card_header do
            hstack justify: :between, align: :center do
              text "#{state[:selected_dir]}/#{state[:selected_file]}"
              hstack spacing: :sm do
                button "Check Syntax", style: :secondary do |s|
                  result = check_syntax(s[:code_content])
                  if result[:ok]
                    # Could show a toast here, but for now just don't show modal
                  else
                    s[:error_message] = result[:message]
                    s[:error_modal_open] = true
                  end
                end

                button "▶ Run" do |s|
                  # Check syntax first
                  result = check_syntax(s[:code_content])
                  if result[:ok]
                    path = file_path(s[:selected_dir], s[:selected_file])
                    run_example(path)
                    s[:last_run_file] = s[:selected_file]
                  else
                    s[:error_message] = result[:message]
                    s[:error_modal_open] = true
                  end
                end
              end
            end
          end

          card_body do
            # Code editor
            code_editor :code_content, language: :ruby, readonly: true, height: "500px"

            # Success message
            if state[:last_run_file] == state[:selected_file]
              alert(variant: :success) do
                text "Launched! Check for a new browser tab."
              end
            end
          end
        end
      else
        card do
          card_body do
            text "Select an example from the sidebar to view its code."
          end
        end
      end
    end
  end

  # Error modal
  modal :error, title: "Syntax Error", size: :md do
    div style: "font-family: monospace; white-space: pre-wrap; background: #fee; padding: 1rem; border-radius: 4px; color: #c00;" do
      text state[:error_message]
    end

    modal_footer do
      button "Close" do |s|
        s[:error_modal_open] = false
      end
    end
  end
end

app.generate.run!
