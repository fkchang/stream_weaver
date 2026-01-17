# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require_relative '../cli'

module StreamWeaver
  module Templates
    # Multi-step wizard template
    # Takes JSON config, handles full flow, returns collected data
    #
    # Usage:
    #   StreamWeaver::Templates::Wizard.run(session: "test", config: {
    #     "title" => "Project Setup",
    #     "steps" => [
    #       { "title" => "Info", "fields" => [
    #         { "type" => "text", "key" => "name", "label" => "Name" },
    #         { "type" => "select", "key" => "type", "options" => ["A", "B"] }
    #       ]},
    #       { "title" => "Features", "fields" => [
    #         { "type" => "checkbox", "key" => "tests", "label" => "Tests" }
    #       ]}
    #     ]
    #   })
    #
    class Wizard
      def initialize(session:, config:, port: nil)
        @session = session
        @config = config
        @port = port || detect_port
        @collected = {}
        @steps = config['steps'] || []
        @title = config['title'] || 'Wizard'
        # Unique run ID to prevent browser autocomplete from previous runs
        @run_id = Time.now.to_i.to_s(36)
      end

      def run
        # Clear any stale submissions before starting
        clear_submissions

        @steps.each_with_index do |step, index|
          step_num = index + 1
          total = @steps.length

          # Render step UI
          push_step(step, step_num, total)

          # Wait for submission
          data = wait_for_submission

          # Collect data (skip _button key, strip run_id suffix from keys)
          data.each do |key, value|
            next if key == '_button'
            # Strip the run_id suffix to get original key name
            original_key = key.to_s.sub(/_#{@run_id}$/, '')
            @collected[original_key] = value
          end
        end

        # Return collected data as JSON
        @collected
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

      def push_step(step, step_num, total)
        dsl = build_step_dsl(step, step_num, total)
        push_dsl(dsl)
      end

      def build_step_dsl(step, step_num, total)
        title = step['title'] || "Step #{step_num}"
        description = step['description']
        fields = step['fields'] || []

        lines = []
        # Show wizard title at top
        lines << "header2 \"#{@title}\""
        lines << "card title: \"#{title} (#{step_num}/#{total})\" do"
        lines << "  text \"#{description}\"" if description

        fields.each do |field|
          lines << build_field_dsl(field)
        end

        # Show collected data so far if not first step
        if step_num > 1 && @collected.any?
          lines << "  text \"\""
          lines << "  text \"Collected so far:\""
          @collected.each do |key, value|
            display_value = value.is_a?(Array) ? value.join(', ') : value.to_s
            lines << "  text \"  #{key}: #{display_value}\""
          end
        end

        lines << "  button \"#{step_num < total ? 'Next' : 'Finish'}\""
        lines << "end"

        lines.join("\n")
      end

      def build_field_dsl(field)
        type = field['type']
        key = field['key']
        # Use run_id in field name to prevent browser autocomplete from previous runs
        unique_key = "#{key}_#{@run_id}"
        label = field['label'] || key.to_s.capitalize

        lines = []
        case type
        when 'text'
          placeholder = field['placeholder'] || label
          lines << "  text \"#{label}:\""
          lines << "  text_field :#{unique_key}, placeholder: \"#{placeholder}\""
        when 'select'
          options = field['options'] || []
          options_str = options.map { |o| "\"#{o}\"" }.join(', ')
          lines << "  text \"#{label}:\""
          lines << "  select :#{unique_key}, [#{options_str}]"
        when 'checkbox'
          lines << "  checkbox :#{unique_key}, \"#{label}\""
        when 'radio'
          options = field['options'] || []
          options_str = options.map { |o| "\"#{o}\"" }.join(', ')
          lines << "  text \"#{label}:\""
          lines << "  radio_group :#{unique_key}, [#{options_str}]"
        else
          lines << "  text \"Unknown field type: #{type}\""
        end
        lines.join("\n")
      end

      def push_dsl(dsl)
        # Render DSL to HTML first
        html = StreamWeaver::CLI.render_dsl_to_html(dsl, session_name: @session)

        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/push")

        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          'content' => html,
          'target' => '#main',
          'action' => 'replace'
        )

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise "Push failed: #{response.code} - #{response.body}"
        end
      end

      def clear_submissions
        # Drain any stale submissions from the queue
        uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/submissions")
        loop do
          response = Net::HTTP.get_response(uri)
          break unless response.is_a?(Net::HTTPSuccess)

          data = JSON.parse(response.body)
          submissions = data['submissions'] || []
          break if submissions.empty?
          # The GET consumes the submission, so just loop until empty
        end
      rescue
        # Ignore errors during cleanup
      end

      def wait_for_submission(timeout: 300)
        start_time = Time.now

        loop do
          if Time.now - start_time > timeout
            raise "Timeout waiting for submission"
          end

          uri = URI("http://localhost:#{@port}/live/#{URI.encode_www_form_component(@session)}/submissions")

          response = Net::HTTP.get_response(uri)
          if response.is_a?(Net::HTTPSuccess)
            data = JSON.parse(response.body)
            submissions = data['submissions'] || []

            if submissions.any?
              return submissions.first['data']
            end
          end

          sleep 0.3
        end
      end

      # Class method for easy invocation
      def self.run(session:, config:, port: nil)
        new(session: session, config: config, port: port).run
      end
    end
  end
end
