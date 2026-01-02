#!/usr/bin/env ruby
# frozen_string_literal: true

# StreamWeaver Examples Browser
# Browse, view, and run StreamWeaver examples with syntax highlighting.
#
# Run with: streamweaver showcase
# (Or: ruby examples/advanced/examples_browser.rb)

require_relative "../../lib/stream_weaver"
require 'net/http'
require 'json'

# Helper module for example discovery
module ExamplesBrowser
  require 'fileutils'

  EXAMPLES_ROOT = File.expand_path("../../", __FILE__)
  PLAYGROUND_ROOT = File.expand_path("../../../examples_playground", __FILE__)

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

  def ensure_playground_exists
    return if File.directory?(PLAYGROUND_ROOT)
    FileUtils.cp_r(EXAMPLES_ROOT, PLAYGROUND_ROOT)
    # Remove the browser itself from playground
    FileUtils.rm_f(File.join(PLAYGROUND_ROOT, "advanced/examples_browser.rb"))
  end

  def playground_path(dir_key, filename)
    File.join(PLAYGROUND_ROOT, dir_key.to_s, filename)
  end

  def original_path(dir_key, filename)
    File.join(EXAMPLES_ROOT, dir_key.to_s, filename)
  end

  def reset_file(dir_key, filename)
    src = original_path(dir_key, filename)
    dst = playground_path(dir_key, filename)
    FileUtils.cp(src, dst)
  end

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
    ensure_playground_exists
    path = playground_path(dir_key, filename)
    return "" unless File.exist?(path)
    File.read(path)
  end

  def file_path(dir_key, filename)
    ensure_playground_exists
    playground_path(dir_key, filename)
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

  def service_port
    info = StreamWeaver::Service.read_pid_file
    info ? info[:port] : StreamWeaver::Service::DEFAULT_PORT
  end

  def run_example_via_service(file_path, name: nil)
    # Load example via service API - returns app info or error
    uri = URI("http://localhost:#{service_port}/load-app")
    params = { file_path: File.expand_path(file_path) }
    params[:name] = name if name

    response = Net::HTTP.post_form(uri, params)
    result = JSON.parse(response.body)

    if result['success']
      {
        ok: true,
        app_id: result['app_id'],
        name: result['name'],
        url: "http://localhost:#{service_port}#{result['url']}"
      }
    else
      { ok: false, error: result['error'] }
    end
  rescue Errno::ECONNREFUSED
    { ok: false, error: "Service not running. Start with: streamweaver showcase" }
  rescue => e
    { ok: false, error: e.message }
  end

  def remove_app_via_service(app_id)
    uri = URI("http://localhost:#{service_port}/remove-app")
    response = Net::HTTP.post_form(uri, { app_id: app_id })
    JSON.parse(response.body)
  rescue
    { 'success' => false }
  end

  def save_file(dir_key, filename, content)
    ensure_playground_exists
    path = playground_path(dir_key, filename)
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

generated_app = app(
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
  # Service mode tracking
  state[:running_app_id] ||= nil
  state[:running_app_url] ||= nil
  state[:running_app_name] ||= nil

  # Track which file is loaded to detect file changes
  # Only read from file when selection changes (not on every request!)
  # This preserves edited content when clicking Save/Run/Check
  loaded_key = "#{state[:selected_dir]}/#{state[:selected_file]}"

  if state[:selected_dir] && state[:selected_file]
    state[:current_file_path] = file_path(state[:selected_dir], state[:selected_file])

    # Only read from file when selection changes OR content is empty (recovery from bad session state)
    if state[:loaded_file_key] != loaded_key || state[:code_content].to_s.strip.empty?
      state[:code_content] = read_file(state[:selected_dir], state[:selected_file])
      state[:loaded_file_key] = loaded_key
      # Clear stale status from previous session
      state[:save_ok] = nil
      state[:syntax_ok] = nil
      state[:reset_ok] = nil
    end
  else
    state[:current_file_path] = nil
    state[:code_content] = ""
    state[:loaded_file_key] = nil
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
                  # Don't clear last_run_file - keep showing which server is running
                  s[:syntax_ok] = nil
                  s[:save_ok] = nil
                  s[:reset_ok] = nil
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

            button "Reset", style: secondary_btn do |s|
              reset_file(s[:selected_dir], s[:selected_file])
              s[:loaded_file_key] = nil  # Force re-read on next render
              s[:reset_ok] = true
              s[:save_ok] = nil
              s[:syntax_ok] = nil
            end

            run_btn_style = "background: #CC342D; border: none; color: white; padding: 8px 16px; border-radius: 6px; font-size: 13px; cursor: pointer;"
            button "▶ Run", style: run_btn_style do |s|
              result = check_syntax(s[:code_content])
              if result[:ok]
                # Auto-save before running so edits take effect
                save_file(s[:selected_dir], s[:selected_file], s[:code_content])
                # Load via service API
                app_result = run_example_via_service(s[:current_file_path], name: "#{s[:selected_dir]}/#{s[:selected_file]}")
                if app_result[:ok]
                  s[:running_app_id] = app_result[:app_id]
                  s[:running_app_url] = app_result[:url]
                  s[:running_app_name] = app_result[:name]
                  s[:syntax_ok] = nil
                  s[:save_ok] = nil
                else
                  s[:error_message] = app_result[:error]
                  s[:error_modal_open] = true
                end
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

        if state[:reset_ok] == true
          div style: status_style do
            text "✓ Reset to original"
          end
        end

        # Running app indicator - shows loaded app with Open/Remove actions
        if state[:running_app_id]
          running_style = "margin-top: 8px; padding: 8px 12px; background: #e8f5e9; border: 1px solid #81c784; border-radius: 4px; font-size: 13px;"
          div style: running_style do
            div style: "display: flex; justify-content: space-between; align-items: center;" do
              text "▶ Loaded: #{state[:running_app_name]}"
              div style: "display: flex; gap: 8px; align-items: center;" do
                external_link_button "Open ↗", url: state[:running_app_url]
                remove_link_style = "background: transparent; border: none; color: #666; cursor: pointer; font-size: 13px; padding: 2px 8px;"
                button "Remove", style: remove_link_style do |s|
                  remove_app_via_service(s[:running_app_id])
                  s[:running_app_id] = nil
                  s[:running_app_url] = nil
                  s[:running_app_name] = nil
                end
              end
            end
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

# Only run directly if executed as main script (not when loaded by service)
generated_app.run! if __FILE__ == $0
