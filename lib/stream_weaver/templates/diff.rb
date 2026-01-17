# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Diff display template
    # Shows code changes with add/remove highlighting
    #
    # Usage:
    #   streamweaver template diff SESSION '{
    #     "title": "Proposed Changes",
    #     "filename": "app.rb",
    #     "changes": [
    #       {"type": "context", "line": "def hello"},
    #       {"type": "remove", "line": "  puts \"old\""},
    #       {"type": "add", "line": "  puts \"new\""},
    #       {"type": "context", "line": "end"}
    #     ],
    #     "actions": ["Apply", "Reject", "Edit"]
    #   }'
    #   # Returns: {"action": "Apply"}
    #
    #   # Or simplified format:
    #   streamweaver template diff SESSION '{
    #     "title": "Changes",
    #     "filename": "app.rb",
    #     "diff": "- old line\n+ new line\n  context"
    #   }'
    #
    class Diff
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @title = config['title']
        @filename = config['filename']
        @changes = config['changes']
        @diff_text = config['diff']
        @actions = config['actions'] || ['Apply', 'Reject']
      end

      def run
        clear_submissions
        push_diff
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

      def push_diff
        html = build_html

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data('content' => html, 'target' => '#main', 'action' => 'replace')

        Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
      end

      def build_html
        diff_lines = build_diff_lines
        diff_html = diff_lines.map { |l| format_diff_line(l) }.join("\n")

        buttons_html = @actions.map.with_index do |action, i|
          variant_class = case action.downcase
          when 'apply', 'accept', 'yes' then 'sw-btn-primary'
          when 'reject', 'cancel', 'no' then 'sw-btn-secondary'
          else i == 0 ? 'sw-btn-primary' : 'sw-btn-secondary'
          end
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
              <pre style="margin: 0; padding: 0; font-family: 'SF Mono', Consolas, monospace; font-size: 0.875rem; line-height: 1.6; overflow-x: auto;">#{diff_html}</pre>
            </div>
            <div style="margin-top: 1rem; display: flex; gap: 0.5rem;">
              #{buttons_html}
            </div>
          </div>
        HTML
      end

      def build_diff_lines
        if @changes
          # Structured format
          @changes.map do |c|
            { type: c['type'] || 'context', line: c['line'] || '' }
          end
        elsif @diff_text
          # Parse diff text format
          @diff_text.split("\n").map do |line|
            case line[0]
            when '+' then { type: 'add', line: line[1..] || '' }
            when '-' then { type: 'remove', line: line[1..] || '' }
            else { type: 'context', line: line.sub(/^\s/, '') }
            end
          end
        else
          []
        end
      end

      def format_diff_line(diff_line)
        type = diff_line[:type]
        line = escape_html(diff_line[:line])

        case type
        when 'add'
          %(<div style="background: #1a3d1a; color: #4ade80; padding: 0 1rem;"><span style="color: #22c55e; user-select: none;">+ </span>#{line}</div>)
        when 'remove'
          %(<div style="background: #3d1a1a; color: #f87171; padding: 0 1rem;"><span style="color: #ef4444; user-select: none;">- </span>#{line}</div>)
        else
          %(<div style="background: #1e1e1e; color: #d4d4d4; padding: 0 1rem;"><span style="color: #666; user-select: none;">  </span>#{line}</div>)
        end
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
