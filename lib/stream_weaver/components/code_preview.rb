# frozen_string_literal: true

module StreamWeaver
  module Components
    # Displays the exact trusted source beside the HTML it rendered.
    class CodePreview < Base
      VALID_LAYOUTS = %i[side_by_side stacked].freeze

      attr_reader :source, :id, :title, :file, :layout, :preview_html, :error

      def initialize(source, id:, title: nil, file: nil, layout: :side_by_side,
                     preview_html: nil, error: nil, **options)
        self.class.validate_layout!(layout)
        @source = source.to_s
        @id = id
        @title = title
        @file = file
        @layout = layout.to_sym
        @preview_html = preview_html
        @error = error
        @options = options
      end

      def self.validate_layout!(layout)
        normalized = layout.to_sym
        return normalized if VALID_LAYOUTS.include?(normalized)

        raise ArgumentError, "unsupported code_preview layout: #{layout.inspect}"
      end

      def code_block
        CodeBlock.new(source, lang: "ruby", file: file)
      end

      def layout_class
        layout.to_s.tr("_", "-")
      end

      def render(view, state)
        view.adapter.render_code_preview(view, self, state)
      end
    end
  end
end
