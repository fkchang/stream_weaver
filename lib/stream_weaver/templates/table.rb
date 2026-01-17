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
        html = build_html

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data('content' => html, 'target' => '#main', 'action' => 'replace')

        Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
      end

      def build_html
        # Build proper HTML table
        header_html = if @headers.any?
          ths = @headers.map { |h| "<th style='padding: 0.75rem 1rem; text-align: left; border-bottom: 2px solid var(--sw-color-border, #e0e0e0);'>#{escape_html(h)}</th>" }.join
          "<thead><tr>#{ths}</tr></thead>"
        else
          ""
        end

        rows_html = @rows.map.with_index do |row, idx|
          if @selectable
            # Clickable row
            btn_id = "btn_row_#{idx}_1"
            tds = row.map { |cell| "<td style='padding: 0.75rem 1rem; border-bottom: 1px solid var(--sw-color-border, #e0e0e0);'>#{escape_html(cell.to_s)}</td>" }.join
            "<tr style='cursor: pointer;' hx-post='/live/#{@session}/action/#{btn_id}' hx-include='[x-model]' hx-target='#main' hx-swap='innerHTML' onmouseover=\"this.style.background='var(--sw-color-bg-hover, #f0f0f0)'\" onmouseout=\"this.style.background=''\">#{tds}</tr>"
          else
            tds = row.map { |cell| "<td style='padding: 0.75rem 1rem; border-bottom: 1px solid var(--sw-color-border, #e0e0e0);'>#{escape_html(cell.to_s)}</td>" }.join
            "<tr>#{tds}</tr>"
          end
        end.join

        buttons_html = if @actions.any? && !@selectable
          btns = @actions.map.with_index do |action, i|
            variant_class = i == 0 ? 'sw-btn-primary' : 'sw-btn-secondary'
            btn_id = "btn_#{action.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')}_#{i + 1}"
            %(<button id="#{btn_id}" class="sw-btn #{variant_class}" hx-post="/live/#{@session}/action/#{btn_id}" hx-include="[x-model]" hx-target="#main" hx-swap="innerHTML">#{escape_html(action)}</button>)
          end.join("\n            ")
          "<div style='margin-top: 1rem; display: flex; gap: 0.5rem;'>#{btns}</div>"
        else
          ""
        end

        <<~HTML
          <div id="main" x-data="{}">
            #{@title ? "<h2 style='margin-bottom: 1rem;'>#{escape_html(@title)}</h2>" : ''}
            <div class="sw-card" style="padding: 0; overflow: hidden;">
              <table style="width: 100%; border-collapse: collapse; font-size: 0.9375rem;">
                #{header_html}
                <tbody>#{rows_html}</tbody>
              </table>
            </div>
            #{buttons_html}
          </div>
        HTML
      end

      def escape_html(text)
        text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
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
