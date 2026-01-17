# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Table display template
    # Shows data in rows/columns with optional row selection
    #
    # Usage:
    #   # Simple table (no interaction, just display):
    #   streamweaver template table SESSION '{
    #     "title": "Users",
    #     "headers": ["Name", "Email", "Role"],
    #     "rows": [
    #       ["Alice", "alice@example.com", "Admin"],
    #       ["Bob", "bob@example.com", "User"]
    #     ]
    #   }'
    #   # Returns: {"action": "ok"}
    #
    #   # With row selection:
    #   streamweaver template table SESSION '{
    #     "title": "Select a file",
    #     "headers": ["File", "Size", "Modified"],
    #     "rows": [
    #       ["app.rb", "12kb", "2 hours ago"],
    #       ["test.rb", "8kb", "yesterday"]
    #     ],
    #     "selectable": true
    #   }'
    #   # Returns: {"selected_row": 0, "selected_data": ["app.rb", "12kb", "2 hours ago"]}
    #
    class Table
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @title = config['title']
        @headers = config['headers'] || []
        @rows = config['rows'] || []
        @selectable = config['selectable'] || false
        @actions = config['actions'] || (@selectable ? [] : ['OK'])
      end

      def run
        clear_submissions
        push_table
        data = wait_for_submission

        button_id = data['_button'] || ''

        if @selectable && button_id.start_with?('btn_row_')
          # Extract row index from button id like "btn_row_0_1"
          row_idx = button_id.sub('btn_row_', '').sub(/_\d+$/, '').to_i
          {
            'selected_row' => row_idx,
            'selected_data' => @rows[row_idx]
          }
        else
          # Regular action button
          action = extract_action(button_id)
          { 'action' => action }
        end
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

      def push_table
        dsl = build_dsl
        html = StreamWeaver::CLI.render_dsl_to_html(dsl, session_name: @session)

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data('content' => html, 'target' => '#main', 'action' => 'replace')

        Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
      end

      def build_dsl
        lines = []
        lines << "header2 \"#{@title}\"" if @title

        if @selectable
          # Selectable rows - each row is a button
          lines << "card do"
          # Header row
          if @headers.any?
            header_text = @headers.join(" | ")
            lines << "  text \"**#{header_text}**\""
            lines << "  text \"---\""
          end
          # Data rows as buttons
          @rows.each_with_index do |row, idx|
            row_text = row.join(" | ")
            lines << "  button \"#{row_text}\", id: \"row_#{idx}\""
          end
          lines << "end"
        else
          # Display-only table
          lines << "card do"
          # Build table using text (simple approach)
          if @headers.any?
            header_text = @headers.join(" | ")
            lines << "  text \"**#{header_text}**\""
            lines << "  text \"#{'─' * [header_text.length, 40].min}\""
          end
          @rows.each do |row|
            row_text = row.map(&:to_s).join(" | ")
            lines << "  text \"#{row_text}\""
          end
          lines << "  text \"\""
          @actions.each_with_index do |action, i|
            variant = i == 0 ? ', variant: :primary' : ''
            lines << "  button \"#{action}\"#{variant}"
          end
          lines << "end"
        end

        lines.join("\n")
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
