# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Information display with optional actions
    # Shows a message and waits for user to acknowledge or choose an action
    #
    # Usage:
    #   # Simple acknowledgment:
    #   streamweaver template info SESSION '{"title":"Done!","message":"Task completed successfully."}'
    #   # Returns: {"action":"ok"}
    #
    #   # With custom actions:
    #   streamweaver template info SESSION '{
    #     "title":"Build Complete",
    #     "message":"3 files compiled, 0 errors",
    #     "details":["main.js (12kb)","styles.css (3kb)","index.html (1kb)"],
    #     "actions":["Deploy","View Logs","Close"]
    #   }'
    #   # Returns: {"action":"Deploy"} or {"action":"View Logs"} etc.
    #
    class Info
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @title = config['title'] || 'Information'
        @message = config['message']
        @details = config['details'] || []
        @actions = config['actions'] || ['OK']
        @variant = config['variant'] # success, warning, error, info
      end

      def run
        clear_submissions
        push_info
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
        # Button id is like "btn_deploy_1" - extract the label
        key = button_id.sub(/^btn_/, '').sub(/_\d+$/, '')

        @actions.each do |action|
          normalized = action.to_s.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
          return action if normalized == key
        end

        key # fallback
      end

      def push_info
        dsl = build_dsl
        html = StreamWeaver::CLI.render_dsl_to_html(dsl, session_name: @session)

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data('content' => html, 'target' => '#main', 'action' => 'replace')

        Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
      end

      def build_dsl
        lines = []
        lines << "card title: \"#{@title}\" do"
        lines << "  text \"#{@message}\"" if @message

        if @details.any?
          lines << "  text \"\""
          @details.each do |detail|
            lines << "  text \"#{detail}\""
          end
        end

        lines << "  text \"\""

        @actions.each_with_index do |action, i|
          variant = i == 0 ? ', variant: :primary' : ''
          lines << "  button \"#{action}\"#{variant}"
        end

        lines << "end"
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
