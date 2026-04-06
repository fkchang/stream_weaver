# frozen_string_literal: true

module StreamWeaver
  module Components
    # Syntax-highlighted code block component using Prism.js CDN.
    #
    # Renders code with optional language-based syntax highlighting,
    # file path header, line truncation for thumbnails, and scrollable container.
    #
    # Uses Prism.js with autoloader plugin for lazy per-language loading.
    # CDN scripts are only included when this component is used.
    #
    # @example Basic usage
    #   code_block("puts 'hello'", lang: "ruby")
    #
    # @example With file header
    #   code_block(code, file: "src/app.rb", lang: "ruby")
    #
    # @example Truncated for thumbnail
    #   code_block(code, truncate: 10, lang: "ruby")
    class CodeBlock < Base
      attr_reader :code, :lang, :file, :truncate, :scroll

      # @param code [String] The source code to display
      # @param lang [String, nil] Language for syntax highlighting (e.g. "ruby", "javascript")
      # @param file [String, nil] File path to show in header bar
      # @param truncate [Integer, nil] Maximum number of lines to show (nil = show all)
      # @param scroll [Boolean] Whether to enable scrolling for long code (default: true)
      # @param options [Hash] Additional options
      def initialize(code, lang: nil, file: nil, truncate: nil, scroll: true, **options)
        @code = code.to_s
        @lang = lang
        @file = file
        @truncate = truncate
        @scroll = scroll
        @options = options
      end

      # Return the display code, truncated if needed
      # @return [String] The code to render
      def display_code
        return @code unless @truncate

        lines = @code.lines
        return @code if lines.length <= @truncate

        lines.first(@truncate).join
      end

      # Whether the code was truncated
      # @return [Boolean]
      def truncated?
        return false unless @truncate

        @code.lines.length > @truncate
      end

      # Total line count of original code
      # @return [Integer]
      def total_lines
        @code.lines.length
      end

      # Prism.js language class (e.g. "language-ruby")
      # @return [String]
      def language_class
        @lang ? "language-#{@lang}" : "language-none"
      end

      def render(view, state)
        view.adapter.render_code_block(view, self, state)
      end
    end
  end
end
