# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Simple choice selector template
    # Shows options as buttons, returns the selected value
    #
    # Usage:
    #   streamweaver template choices SESSION '{"title":"Pick a color","options":["Red","Green","Blue"]}'
    #   # Returns: {"choice":"Green"}
    #
    #   # With descriptions:
    #   streamweaver template choices SESSION '{
    #     "title":"Database",
    #     "description":"Which database to use?",
    #     "options":[
    #       {"label":"PostgreSQL","description":"Best for complex queries"},
    #       {"label":"SQLite","description":"Simple, file-based"},
    #       {"label":"MySQL","description":"Popular, widely supported"}
    #     ]
    #   }'
    #
    class Choices
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @title = config['title'] || 'Choose an option'
        @description = config['description']
        @options = config['options'] || []
        @run_id = Time.now.to_i.to_s(36)
      end

      def run
        clear_submissions
        push_choices
        data = wait_for_submission

        # Extract choice from button id (btn_LABEL_1 format)
        button_id = data['_button'] || ''
        # Button id is like "btn_postgresql_1" - extract the label part
        choice_key = button_id.sub(/^btn_/, '').sub(/_\d+$/, '')

        # Find matching option
        selected = find_option_by_key(choice_key)

        { 'choice' => selected }
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

      def find_option_by_key(key)
        @options.each do |opt|
          if opt.is_a?(Hash)
            label = opt['label']
            # Normalize: downcase, replace spaces with underscores
            normalized = label.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
            return label if normalized == key
          else
            normalized = opt.to_s.downcase.gsub(/\s+/, '_').gsub(/[^a-z0-9_]/, '')
            return opt if normalized == key
          end
        end
        key # fallback
      end

      def push_choices
        dsl = build_dsl
        html = StreamWeaver::CLI.render_dsl_to_html(dsl, session_name: @session)

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")
        request = Net::HTTP::Post.new(uri)
        request.set_form_data('content' => html, 'target' => '#main', 'action' => 'replace')

        Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(request) }
      end

      def build_dsl
        lines = []
        lines << "header2 \"#{@title}\""
        lines << "text \"#{@description}\"" if @description
        lines << "card do"

        @options.each do |opt|
          if opt.is_a?(Hash)
            label = opt['label']
            desc = opt['description']
            lines << "  button \"#{label}\""
            lines << "  text \"#{desc}\", style: :muted" if desc
            lines << "  text \"\""
          else
            lines << "  button \"#{opt}\""
          end
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
