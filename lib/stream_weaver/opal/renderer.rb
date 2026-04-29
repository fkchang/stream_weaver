# frozen_string_literal: true

module StreamWeaver
  module Opal
    class OpalRenderer
      attr_reader :adapter

      def initialize(adapter, state)
        @adapter = adapter
        @state = state
        @output = []
      end

      # Block tags — open tag, yield, close tag
      %w[div span p ul ol li h1 h2 h3 h4 h5 h6 form label select textarea
         nav header footer main section article aside table thead tbody tr th td
         button fieldset legend details summary strong em a].each do |tag|
        define_method(tag) do |**attrs, &block|
          @output << "<#{tag}#{attrs_to_html(attrs)}>"
          block&.call
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

      def html_escape(str)
        str.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end
    end
  end
end
