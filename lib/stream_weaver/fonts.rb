# frozen_string_literal: true

require_relative "delivery"

module StreamWeaver
  # Turns a declarative fonts list into what a page head loads.
  #
  # Accepts an array of:
  #   "Family:wght@400;700"            — string shorthand (treated as Google font)
  #   { google: "Family:wght@400;700" } — explicit Google font
  #   { family: "Foo", src: "fonts/foo.woff2" } — self-hosted: an @font-face whose
  #     file reaches the page through the host's Delivery. Optional weight:
  #     ("400", "100 900") and style:. A relative src resolves against the
  #     declaring file (see .resolve).
  module Fonts
    # The framework's own fonts: Source Sans 3 for body text, Crimson Pro
    # for the document theme.
    BASE_HREF = "https://fonts.googleapis.com/css2?family=Crimson+Pro:wght@400;500;600&family=Source+Sans+3:wght@400;500;600;700&display=swap"

    # Build a combined Google Fonts href from the entries that declare Google fonts.
    #
    # @param fonts [Array<String, Hash>]
    # @return [String, nil] Fully-qualified googleapis CSS2 URL, or nil if no Google fonts
    def self.google_fonts_href(fonts)
      google_families = fonts.filter_map do |entry|
        case entry
        when String then entry
        when Hash   then entry[:google]
        end
      end
      return nil if google_families.empty?

      families = google_families.map { |f| "family=#{f}" }.join("&")
      "https://fonts.googleapis.com/css2?#{families}&display=swap"
    end

    FORMATS = { ".woff2" => "woff2", ".woff" => "woff", ".ttf" => "truetype", ".otf" => "opentype" }.freeze

    # @font-face CSS for every self-hosted entry, its file delivered by `delivery`.
    #
    # @param fonts [Array<String, Hash>]
    # @param delivery [Delivery::Served, Delivery::Inline, Delivery::Copied]
    # @return [String] CSS, empty when nothing is self-hosted
    def self.font_face_css(fonts, delivery)
      fonts.select { |entry| entry.is_a?(Hash) && entry[:src] }.map do |entry|
        format = FORMATS[File.extname(entry[:src].to_s).downcase]
        src = delivery.ref(entry[:src], :font)
        rules = ["font-family: '#{entry[:family]}'", "src: #{src}#{" format('#{format}')" if format}",
                 ("font-weight: #{entry[:weight]}" if entry[:weight]),
                 ("font-style: #{entry[:style]}" if entry[:style]), "font-display: swap"]
        "@font-face { #{rules.compact.join('; ')}; }"
      end.join("\n")
    end

    # Makes a self-hosted entry's relative src absolute against `dir`.
    #
    # @param fonts [Array<String, Hash>]
    # @param dir [String] the declaring file's directory
    # @return [Array<String, Hash>]
    def self.resolve(fonts, dir)
      fonts.map do |entry|
        next entry unless entry.is_a?(Hash) && entry[:src] && !entry[:src].to_s.match?(Delivery::URL)

        entry.merge(src: File.expand_path(entry[:src], dir))
      end
    end
  end
end
