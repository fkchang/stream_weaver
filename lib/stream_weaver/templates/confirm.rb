# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Simple confirmation dialog
    # Returns {"confirmed": true/false}
    #
    # Usage:
    #   streamweaver template confirm SESSION '{"title":"Delete files?","message":"This will remove 3 files permanently."}'
    #   # Returns: {"confirmed":true} or {"confirmed":false}
    #
    #   # Custom button labels:
    #   streamweaver template confirm SESSION '{"title":"Deploy?","yes":"Deploy Now","no":"Cancel"}'
    #
    class Confirm
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @title = config['title'] || 'Confirm'
        @message = config['message']
        @yes_label = config['yes'] || 'Yes'
        @no_label = config['no'] || 'No'
      end

      def run
        clear_submissions
        push_dialog
        data = wait_for_submission

        button_id = data['_button'] || ''
        confirmed = button_id.include?('yes') || button_id.include?(@yes_label.downcase.gsub(/\s+/, '_'))

        { 'confirmed' => confirmed }
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

      def push_dialog
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
        lines << "  text \"\""
        lines << "  button \"#{@yes_label}\", variant: :primary"
        lines << "  button \"#{@no_label}\", variant: :secondary"
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
