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

  def save_file(dir_key, filename, content)
    path = File.join(EXAMPLES_ROOT, dir_key.to_s, filename)
    File.write(path, content)
    { ok: true, message: "Saved #{filename}" }
  rescue => e
    { ok: false, message: "Failed to save: #{e.message}" }
  end

  def all_dir_keys
    DIRECTORIES.keys
  end
end

# CodeMirror 5 CDN URLs
CODEMIRROR_CSS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css"
CODEMIRROR_JS = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"
CODEMIRROR_RUBY = "https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/ruby/ruby.min.js"

app = StreamWeaver::App.new(
  "Example Playground",
  layout: :fluid,
  theme: :default,
  stylesheets: [CODEMIRROR_CSS],
  scripts: [CODEMIRROR_JS, CODEMIRROR_RUBY],
  components: [ExamplesBrowser]
) do
  # Initialize state - derive examples fresh each time (not stored in session)
  examples = discover_examples
  state[:expanded_dirs] ||= [:basic]
  state[:selected_dir] ||= :basic
  state[:selected_file] ||= examples.first&.dig(:files)&.first
  state[:error_modal_open] ||= false
  state[:error_message] ||= ""
  state[:last_run_file] ||= nil

  # ALWAYS derive current_file_path and code_content from selected_dir/selected_file
  # This avoids storing large file content in session cookies (4KB limit!)
  if state[:selected_dir] && state[:selected_file]
    state[:current_file_path] = file_path(state[:selected_dir], state[:selected_file])
    state[:code_content] = read_file(state[:selected_dir], state[:selected_file])
  else
    state[:current_file_path] = nil
    state[:code_content] = ""
  end

  # Main layout
  div style: "display: flex; gap: 20px;" do
    # Sidebar - file browser (Finder-style)
    div style: "width: 220px; flex-shrink: 0;" do
      # Expand/Collapse all buttons
      div style: "display: flex; gap: 4px; margin-bottom: 8px;" do
        small_btn = "padding: 4px 8px; font-size: 11px; background: #fff; border: 1px solid #ccc; border-radius: 4px; cursor: pointer; color: #666;"
        button "Expand All", style: small_btn do |s|
          s[:expanded_dirs] = all_dir_keys
        end
        button "Collapse All", style: small_btn do |s|
          s[:expanded_dirs] = []
        end
      end

      div style: "background: #f5f5f5; border: 1px solid #e0e0e0; border-radius: 6px; padding: 8px;" do
        examples.each do |dir|
          is_expanded = state[:expanded_dirs].include?(dir[:key])
          disclosure = is_expanded ? "▾" : "▸"

          # Folder row (clickable to expand/collapse)
          folder_style = "display: block !important; padding: 6px 8px !important; cursor: pointer !important; border-radius: 4px !important; font-weight: 500 !important; color: #333 !important; font-size: 13px !important; border: none !important; background: transparent !important; width: 100% !important; text-align: left !important;"
          folder_label = "#{disclosure} 📁 #{dir[:label]} (#{dir[:files].length})"
          button folder_label, style: folder_style do |s|
            if s[:expanded_dirs].include?(dir[:key])
              s[:expanded_dirs] = s[:expanded_dirs] - [dir[:key]]
            else
              s[:expanded_dirs] = s[:expanded_dirs] + [dir[:key]]
            end
          end

          # File list (if expanded)
          if is_expanded
            div do
              dir[:files].each do |filename|
                is_selected = state[:selected_dir] == dir[:key] && state[:selected_file] == filename
                bg_color = is_selected ? "#d4e5f7" : "transparent"
                text_color = is_selected ? "#333" : "#555"
                file_style = "display: block !important; padding: 5px 8px 5px 28px !important; cursor: pointer !important; border-radius: 4px !important; color: #{text_color} !important; background: #{bg_color} !important; font-size: 13px !important; border: none !important; width: 100% !important; text-align: left !important; overflow: hidden !important; text-overflow: ellipsis !important; white-space: nowrap !important;"

                button filename, style: file_style do |s|
                  s[:selected_dir] = dir[:key]
                  s[:selected_file] = filename
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
        div style: "display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;" do
          div style: "font-family: ui-monospace, SFMono-Regular, 'SF Mono', Menlo, monospace; font-size: 13px; color: #666;" do
            text "#{state[:selected_dir]}/#{state[:selected_file]}"
          end
          div style: "display: flex; gap: 8px;" do
            secondary_btn = "background: white; border: 1px solid #ccc; color: #333; padding: 8px 16px; border-radius: 6px; font-size: 13px; cursor: pointer;"

            button "Check", style: secondary_btn do |s|
              result = check_syntax(s[:code_content])
              if result[:ok]
                s[:syntax_ok] = true
                s[:save_ok] = nil
              else
                s[:syntax_ok] = false
                s[:save_ok] = nil
                s[:error_message] = result[:message]
                s[:error_modal_open] = true
              end
            end

            button "Save", style: secondary_btn do |s|
              result = check_syntax(s[:code_content])
              if result[:ok]
                save_result = save_file(s[:selected_dir], s[:selected_file], s[:code_content])
                s[:save_ok] = save_result[:ok]
                s[:syntax_ok] = nil
              else
                s[:error_message] = result[:message]
                s[:error_modal_open] = true
              end
            end

            run_btn_style = "background: #CC342D; border: none; color: white; padding: 8px 16px; border-radius: 6px; font-size: 13px; cursor: pointer;"
            button "▶ Run", style: run_btn_style do |s|
              result = check_syntax(s[:code_content])
              if result[:ok]
                run_example(s[:current_file_path])
                s[:last_run_file] = s[:selected_file]
                s[:syntax_ok] = nil
                s[:save_ok] = nil
              else
                s[:error_message] = result[:message]
                s[:error_modal_open] = true
              end
            end
          end
        end

        # Code editor with syntax highlighting (editable)
        code_editor :code_content, language: :ruby, readonly: false, height: "500px"

        # Status messages
        status_style = "margin-top: 8px; padding: 8px 12px; background: #d4edda; color: #155724; border-radius: 4px; font-size: 13px;"
        if state[:syntax_ok] == true
          div style: status_style do
            text "✓ Syntax OK"
          end
        end

        if state[:save_ok] == true
          div style: status_style do
            text "✓ Saved"
          end
        end

        if state[:last_run_file] == state[:selected_file]
          div style: status_style do
            text "✓ Launched - check for new browser tab"
          end
        end
      else
        div style: "color: #888; padding: 40px; text-align: center;" do
          text "Select an example from the sidebar to view its code."
        end
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
