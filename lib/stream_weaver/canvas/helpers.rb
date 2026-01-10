# frozen_string_literal: true

module StreamWeaver
  module Canvas
    # High-level helper methods for common canvas patterns.
    # Generates DSL code and parses results for pick, confirm, and form operations.
    module Helpers
      module_function

      # Generate DSL for a single-choice picker
      # @param title [String] The title/prompt
      # @param choices [Array<String>] Available choices
      # @return [String] DSL code
      def pick_dsl(title, choices)
        choices_str = choices.map { |c| "\"#{c}\"" }.join(", ")

        <<~DSL
          header1 "#{title}"
          radio_group :choice, [#{choices_str}]
          button "Select", id: "btn_submit"
        DSL
      end

      # Generate DSL for a confirmation dialog
      # @param message [String] The confirmation message
      # @param yes_label [String] Label for confirm button (default: "Confirm")
      # @param no_label [String] Label for cancel button (default: "Cancel")
      # @return [String] DSL code
      def confirm_dsl(message, yes_label: "Confirm", no_label: "Cancel")
        <<~DSL
          header1 "#{message}"
          hstack do
            button "#{no_label}", id: "btn_cancel", style: :secondary
            button "#{yes_label}", id: "btn_confirm"
          end
        DSL
      end

      # Generate DSL for a form with specified fields
      # @param title [String] The form title
      # @param fields [Hash] Field definitions { name: { type: :text, ... }, ... }
      # @return [String] DSL code
      def form_dsl(title, fields)
        field_dsl = fields.map do |name, config|
          case config[:type]
          when :text
            placeholder = config[:placeholder] ? ", placeholder: \"#{config[:placeholder]}\"" : ""
            "text_field :#{name}#{placeholder}"
          when :textarea
            placeholder = config[:placeholder] ? ", placeholder: \"#{config[:placeholder]}\"" : ""
            rows = config[:rows] ? ", rows: #{config[:rows]}" : ""
            "text_area :#{name}#{placeholder}#{rows}"
          when :radio
            choices_str = config[:choices].map { |c| "\"#{c}\"" }.join(", ")
            "radio_group :#{name}, [#{choices_str}]"
          when :select
            choices_str = config[:choices].map { |c| "\"#{c}\"" }.join(", ")
            "select :#{name}, [#{choices_str}]"
          when :checkbox
            label = config[:label] || name.to_s.capitalize
            "checkbox :#{name}, \"#{label}\""
          else
            "text_field :#{name}"
          end
        end.join("\n")

        <<~DSL
          header1 "#{title}"
          #{field_dsl}
          button "Submit", id: "btn_submit"
        DSL
      end

      # Parse pick result from event data
      # @param event_data [Hash] Event data from browser
      # @return [String, nil] Selected choice
      def parse_pick_result(event_data)
        event_data[:choice] || event_data["choice"]
      end

      # Parse confirm result from event data
      # @param event_data [Hash] Event data from browser
      # @return [Boolean] true if confirmed, false if cancelled
      def parse_confirm_result(event_data)
        button = event_data[:_button] || event_data["_button"] || ""
        button.include?("confirm")
      end

      # Parse form result from event data
      # @param event_data [Hash] Event data from browser
      # @param field_names [Array<Symbol>] Expected field names
      # @return [Hash] Form field values
      def parse_form_result(event_data, field_names)
        result = {}
        field_names.each do |name|
          key = name.to_sym
          result[key] = event_data[key] || event_data[name.to_s]
        end
        result
      end
    end
  end
end
