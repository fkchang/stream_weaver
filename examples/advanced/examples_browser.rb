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
    basic: "Basic",
    agentic: "Agentic",
    components: "Components",
    layout: "Layout",
    styling: "Styling",
    advanced: "Advanced"
  }.freeze

  def discover_examples
    DIRECTORIES.map do |dir_key, label|
      dir_path = File.join(EXAMPLES_ROOT, dir_key.to_s)
      next unless File.directory?(dir_path)

      files = Dir.glob(File.join(dir_path, "*.rb"))
        .map { |f| File.basename(f) }
        .reject { |f| SKIP_FILES.include?(f) }
        .sort

      { key: dir_key, label: label, files: files }
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
    temp_file = "/tmp/sw_syntax_check_#{Process.pid}.rb"
    File.write(temp_file, code)

    stdout, stderr, status = Open3.capture3("ruby", "-c", temp_file)
    File.delete(temp_file) rescue nil

    if status.success?
      { ok: true, message: "Syntax OK" }
    else
      error = stderr.gsub(temp_file, "example.rb")
      { ok: false, message: error.strip }
    end
  end

  def run_example(file_path)
    SPAWNED_PIDS.each { |pid| Process.kill('TERM', pid) rescue nil }
    SPAWNED_PIDS.clear

    pid = spawn("ruby", file_path)
    Process.detach(pid)
    SPAWNED_PIDS << pid
    pid
  end

  def kill_servers
    SPAWNED_PIDS.each { |pid| Process.kill('TERM', pid) rescue nil }
    SPAWNED_PIDS.clear
  end
end

# CodeMirror 5 CDN URLs
CODEMIRROR_CSS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css"
CODEMIRROR_JS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"
CODEMIRROR_RUBY = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/ruby/ruby.min.js"

app = StreamWeaver::App.new(
  "Examples",
  layout: :fluid,
  theme: :default,
  stylesheets: [CODEMIRROR_CSS],
  scripts: [CODEMIRROR_JS, CODEMIRROR_RUBY],
  components: [ExamplesBrowser]
) do
  # Initialize state
  state[:examples] ||= discover_examples
  state[:expanded_dirs] ||= [:basic]
  state[:selected_dir] ||= :basic
  state[:selected_file] ||= state[:examples].first&.dig(:files)&.first
  state[:error_modal_open] ||= false
  state[:error_message] ||= ""
  state[:last_run_file] ||= nil

  # Initialize file content and path on first load
  unless state[:current_file_path]
    if state[:selected_dir] && state[:selected_file]
      state[:current_file_path] = file_path(state[:selected_dir], state[:selected_file])
      state[:code_content] = read_file(state[:selected_dir], state[:selected_file])
    else
      state[:code_content] ||= ""
    end
  end

  # Inject custom CSS
  div style: "display:none" do
    # Hack: inject style via a hidden div
  end

  # Header row
  div style: "display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;" do
    header2 "StreamWeaver Examples"
    if SPAWNED_PIDS.any?
      button "Kill Server", style: :secondary do |s|
        kill_servers
        s[:last_run_file] = nil
      end
    end
  end

  # Main layout
  div style: "display: flex; gap: 16px;" do
    # Sidebar - file browser
    div style: "width: 220px; flex-shrink: 0; overflow: hidden;" do
      div style: "background: #fafafa; border: 1px solid #e0e0e0; border-radius: 6px; padding: 8px; overflow: hidden;" do
        state[:examples].each do |dir|
          is_expanded = state[:expanded_dirs].include?(dir[:key])
          folder_icon = is_expanded ? "▼" : "▶"

          # Folder row (clickable to expand/collapse)
          button "#{folder_icon} 📁 #{dir[:label]} (#{dir[:files].length})", style: "display: block; padding: 6px 8px; cursor: pointer; font-weight: 500; color: #333; border-radius: 4px; border: none; background: transparent; width: 100%; text-align: left; font-size: 13px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" do |s|
            if s[:expanded_dirs].include?(dir[:key])
              s[:expanded_dirs] = s[:expanded_dirs] - [dir[:key]]
            else
              s[:expanded_dirs] = s[:expanded_dirs] + [dir[:key]]
            end
          end

          # File list (if expanded)
          if is_expanded
            div style: "margin-left: 16px;" do
              dir[:files].each do |filename|
                is_selected = state[:selected_dir] == dir[:key] && state[:selected_file] == filename
                bg = is_selected ? "#0066cc" : "transparent"
                color = is_selected ? "white" : "#0066cc"

                button filename, style: "display: block; padding: 4px 8px; color: #{color}; background: #{bg}; border: none; border-radius: 4px; width: 100%; text-align: left; font-size: 13px; cursor: pointer; margin: 2px 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" do |s|
                  s[:selected_dir] = dir[:key]
                  s[:selected_file] = filename
                  s[:current_file_path] = file_path(dir[:key], filename)
                  s[:code_content] = read_file(dir[:key], filename)
                  s[:last_run_file] = nil
                  s[:syntax_ok] = nil
                end
              end
            end
          end
        end
      end
    end

    # Main content
    div style: "flex: 1; min-width: 0;" do
      if state[:selected_file]
        # Header with file path and buttons
        div style: "display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;" do
          text "#{state[:selected_dir]}/#{state[:selected_file]}"
          hstack spacing: :sm do
            button "Check", style: :secondary do |s|
              result = check_syntax(s[:code_content])
              if result[:ok]
                s[:syntax_ok] = true
              else
                s[:syntax_ok] = false
                s[:error_message] = result[:message]
                s[:error_modal_open] = true
              end
            end

            button "▶ Run" do |s|
              result = check_syntax(s[:code_content])
              if result[:ok]
                # Use stored path to ensure we run the correct file
                run_example(s[:current_file_path])
                s[:last_run_file] = s[:selected_file]
                s[:syntax_ok] = nil
              else
                s[:error_message] = result[:message]
                s[:error_modal_open] = true
              end
            end
          end
        end

        # Code display with syntax highlighting
        code_editor :code_content, language: :ruby, readonly: true, height: "500px"

        # Status messages
        if state[:syntax_ok] == true
          div style: "margin-top: 8px; padding: 8px 12px; background: #d4edda; color: #155724; border-radius: 4px; font-size: 13px;" do
            text "✓ Syntax OK"
          end
        end

        if state[:last_run_file] == state[:selected_file]
          div style: "margin-top: 8px; padding: 8px 12px; background: #d4edda; color: #155724; border-radius: 4px; font-size: 13px;" do
            text "✓ Launched - check for new browser tab"
          end
        end
      else
        text "Select an example from the sidebar."
      end
    end
  end

  # Error modal
  modal :error, title: "Syntax Error", size: :md do
    div style: "font-family: monospace; white-space: pre-wrap; background: #fee; padding: 1rem; border-radius: 4px; color: #c00; font-size: 13px;" do
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
