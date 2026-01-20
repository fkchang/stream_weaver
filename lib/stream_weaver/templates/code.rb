# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Code display template
    # Shows code with optional filename and actions
    #
    # Usage:
    #   streamweaver template code SESSION '{
    #     "title": "Generated Code",
    #     "filename": "app.rb",
    #     "language": "ruby",
    #     "code": "def hello\n  puts \"Hello\"\nend",
    #     "actions": ["Copy", "Apply", "Cancel"]
    #   }'
    #   # Returns: {"action": "Apply"}
    #
    class Code
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @title = config['title']
        @filename = config['filename']
        @language = config['language'] || 'text'
        @code = config['code'] || ''
        @actions = config['actions'] || ['OK']
        @line_numbers = config['line_numbers'] != false
      end

      def run
        clear_submissions
        push_code
        data = wait_for_submission

        button_id = data['_button'] || ''
        action = extract_action(button_id)
        { 'action' => action }
      end

      private

      def detect_port
        pid_file = File.expand_path('~/.streamweaver/service.pid')
        return 4576 unless File.exist?(pid_file)
        data = JSON.parse(File.read(pid_file))
        data['port'] || 4576
      rescue
        4576
      end

      def extract_action(button_id)
        key = button_id.sub(/^btn_/, '').sub(/_\d+$/, '')
        @actions.each do |action|
          normalized = action.to_s.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
          return action if normalized == key
        end
        key
      end

      def push_code
        # Build HTML directly for better code formatting
        html = build_html

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data('content' => html, 'target' => '#main', 'action' => 'replace')

        Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
      end

      def build_html
        escaped_code = escape_html(@code)

        # Add line numbers if enabled
        if @line_numbers
          lines = escaped_code.split("\n")
          numbered_lines = lines.each_with_index.map do |line, i|
            line_num = (i + 1).to_s.rjust(3)
            "<span style='color: #666; user-select: none;'>#{line_num}</span>  #{line}"
          end
          escaped_code = numbered_lines.join("\n")
        end

        buttons_html = @actions.map.with_index do |action, i|
          variant_class = i == 0 ? 'sw-btn-primary' : 'sw-btn-secondary'
          btn_id = "btn_#{action.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')}_#{i + 1}"
          %(<button id="#{btn_id}" class="sw-btn #{variant_class}"
            hx-post="/live/#{@session}/action/#{btn_id}"
            hx-include="[x-model]"
            hx-target="#main"
            hx-swap="innerHTML">#{escape_html(action)}</button>)
        end.join("\n          ")

        <<~HTML
          <div id="main" x-data="{}">
            #{@title ? "<h2 style='margin-bottom: 1rem;'>#{escape_html(@title)}</h2>" : ''}
            <div class="sw-card" style="padding: 0; overflow: hidden;">
              #{@filename ? "<div style='padding: 0.5rem 1rem; background: var(--sw-color-bg); border-bottom: 1px solid var(--sw-color-border); font-size: 0.875rem; color: var(--sw-color-text-muted);'>#{escape_html(@filename)}</div>" : ''}
              <pre style="margin: 0; padding: 1rem; background: #1e1e1e; color: #d4d4d4; overflow-x: auto; font-family: 'SF Mono', Consolas, monospace; font-size: 0.875rem; line-height: 1.5;"><code>#{escaped_code}</code></pre>
            </div>
            <div style="margin-top: 1rem; display: flex; gap: 0.5rem;">
              #{buttons_html}
            </div>
          </div>
        HTML
      end

      def escape_html(text)
        text.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
          .gsub('"', '&quot;')
      end

      def clear_submissions
        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/submissions")
        loop do
          response = Net::HTTP.get_response(uri)
          break unless response.is_a?(Net::HTTPSuccess)
          data = JSON.parse(response.body)
          break if (data['submissions'] || []).empty?
        end
      rescue
        # ignore
      end

      def wait_for_submission(timeout: 300)
        start_time = Time.now
        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/submissions")

        loop do
          raise "Timeout" if Time.now - start_time > timeout

          response = Net::HTTP.get_response(uri)
          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            submissions = data['submissions'] || []
            return submissions.first['data'] if submissions.any?
          end

          sleep 0.3
        end
      end

      def self.run(session:, config:, port: nil)
        new(session: session, config: config, port: port).run
      end
    end
  end
end
