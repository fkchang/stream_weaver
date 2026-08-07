# frozen_string_literal: true

require "cgi"

module StreamWeaver
  module Opal
    class OpalRenderer
      attr_reader :adapter

      def initialize(adapter, state)
        @adapter = adapter
        @state = state
        @output = []
      end

      # Block tags — open tag, yield, close tag.
      # If the block returns a String and nothing was added to @output inside the block,
      # treat the return value as plain text (mirrors Phlex behavior for simple text blocks).
      %w[div span p ul ol li h1 h2 h3 h4 h5 h6 form label select textarea
         nav header footer main section article aside table thead tbody tr th td
         button fieldset legend details summary strong em a
         pre code blockquote figure figcaption caption style script small
         time mark sub sup abbr dl dt dd].each do |tag|
        define_method(tag) do |**attrs, &block|
          @output << "<#{tag}#{attrs_to_html(attrs)}>"
          if block
            before_len = @output.length
            result = block.call
            # If block didn't add anything (returned a string), emit it as plain text
            if @output.length == before_len && result.is_a?(String)
              @output << html_escape(result)
            end
          end
          @output << "</#{tag}>"
        end
      end

      # Void (self-closing) tags
      %w[input hr br img link meta].each do |tag|
        define_method(tag) do |**attrs|
          @output << "<#{tag}#{attrs_to_html(attrs)}>"
        end
      end

      def plain(text)
        @output << html_escape(text.to_s)
      end

      def raw(html)
        @output << html.to_s
      end

      # Phlex marks trusted strings with #safe before #raw will emit them.
      # Here #raw already emits verbatim, so this is just the identity function
      # -- it exists so shared renderers can call view.raw(view.safe(css))
      # unchanged in both adapters.
      def safe(html) = html.to_s

      def to_html
        @output.join
      end

      private

      def attrs_to_html(attrs)
        return "" if attrs.empty?
        " " + attrs.filter_map do |k, v|
          next if v == false
          key = k.to_s.tr("_", "-")
          v == true ? key : "#{key}=\"#{html_escape(v.to_s)}\""
        end.join(" ")
      end

      def html_escape(str) = CGI.escapeHTML(str.to_s)
    end
  end
end
