# frozen_string_literal: true

module StreamWeaver
  # Builds Google Fonts link tags from a declarative fonts list.
  #
  # Accepts an array of:
  #   "Family:wght@400;700"            — string shorthand (treated as Google font)
  #   { google: "Family:wght@400;700" } — explicit Google font
  #   { src: "/fonts/foo.woff2", family: "Foo" } — self-hosted (future, not yet emitted)
  module Fonts
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

    # Returns true if any entry is a Google font.
    def self.google_fonts?(fonts)
      fonts.any? { |e| e.is_a?(String) || (e.is_a?(Hash) && e.key?(:google)) }
    end
  end
end
