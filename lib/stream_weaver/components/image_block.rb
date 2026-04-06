# frozen_string_literal: true

require 'base64'

module StreamWeaver
  module Components
    # Image display component with optional caption and base64 export support.
    #
    # Renders an image with optional caption text below it.
    # Supports local file paths, URLs, and base64 data URI conversion
    # for self-contained HTML export.
    #
    # @example Basic usage
    #   image_block("photo.png", alt: "A photo")
    #
    # @example With caption
    #   image_block("diagram.svg", caption: "Figure 1: Architecture")
    #
    # @example Base64 export mode
    #   image_block("local/image.png", base64: true)
    class ImageBlock < Base
      attr_reader :src, :alt, :caption, :base64

      # @param src [String] Image source (URL or file path)
      # @param alt [String] Alt text for accessibility (default: "")
      # @param caption [String, nil] Caption text to display below the image
      # @param base64 [Boolean] Convert local file to base64 data URI (default: false)
      # @param options [Hash] Additional options
      def initialize(src, alt: "", caption: nil, base64: false, **options)
        @src = src.to_s
        @alt = alt.to_s
        @caption = caption
        @base64 = base64
        @options = options
      end

      # Resolve the image source, converting to data URI if base64 mode is enabled.
      # @return [String] The resolved src attribute value
      def resolved_src
        return @src unless @base64 && File.exist?(@src)

        mime = mime_type(@src)
        data = Base64.strict_encode64(File.binread(@src))
        "data:#{mime};base64,#{data}"
      end

      def render(view, state)
        view.adapter.render_image_block(view, self, state)
      end

      private

      # Detect MIME type from file extension
      # @param path [String] File path
      # @return [String] MIME type
      def mime_type(path)
        case File.extname(path).downcase
        when ".png"  then "image/png"
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".gif"  then "image/gif"
        when ".svg"  then "image/svg+xml"
        when ".webp" then "image/webp"
        when ".bmp"  then "image/bmp"
        when ".ico"  then "image/x-icon"
        else "application/octet-stream"
        end
      end
    end
  end
end
