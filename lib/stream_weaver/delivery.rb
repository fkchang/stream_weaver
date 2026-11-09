# frozen_string_literal: true

require "base64"
require "digest"
require "fileutils"
require_relative "component_assets"

module StreamWeaver
  # How a local file (a stylesheet, a script or a font) reaches a page.
  # Each host has one Delivery, and every Delivery answers one question:
  # ref(path, kind) returns the markup that loads `path` as `kind` on that
  # host. kind is :stylesheet (a tag), :script (a tag) or :font (a CSS
  # url(), for an @font-face src).
  #
  # - Served: a /sw-asset URL the host's server answers (standalone, the
  #   canvas bridge, the reader; see AssetRoute).
  # - Inline: the file's content in the page itself (export), with the
  #   relative url() references inside a stylesheet inlined too.
  # - Copied: a copy beside the page with a relative href (an Opal build).
  #
  # A remote URL or a data: URI is not a local file: every Delivery passes
  # it through unchanged. A /sw-asset URL (App#local_asset and stylesheets:
  # produce them) names a registered local file, so Inline and Copied
  # deliver that file.
  module Delivery
    URL = %r{\A(?:[a-z][a-z0-9+.-]*:|//)}i
    SERVED = %r{\A/sw-asset/(\h+)/}

    MIME_TYPES = {
      "css" => "text/css", "js" => "application/javascript", "mjs" => "application/javascript",
      "png" => "image/png", "jpg" => "image/jpeg", "jpeg" => "image/jpeg", "gif" => "image/gif",
      "svg" => "image/svg+xml", "webp" => "image/webp", "ico" => "image/x-icon",
      "woff2" => "font/woff2", "woff" => "font/woff", "ttf" => "font/ttf", "otf" => "font/otf"
    }.freeze

    # A url() inside CSS, its quote, and its target.
    CSS_URL = /url\(\s*(['"]?)([^'")]+)\1\s*\)/
    # Targets a stylesheet resolves itself: absolute, remote, data: or a fragment.
    CSS_URL_KEEP = %r{\A(?:[a-z][a-z0-9+.-]*:|/|#)}i

    module_function

    # @return [String, nil] the local file `path` names, or nil for a URL
    #   (a root-relative "/app.css" is a URL unless that file exists)
    def local_file(path)
      path = path.to_s
      return ComponentAssets.resolve_file(Regexp.last_match(1)) if path.match(SERVED)

      path if !path.match?(URL) && File.file?(path)
    end

    def mime_type(path)
      MIME_TYPES[File.extname(path).delete(".").downcase] || "application/octet-stream"
    end

    # The tag (or CSS url()) that loads `href` as `kind`.
    def tag(href, kind)
      case kind
      when :stylesheet then %(<link rel="stylesheet" href="#{attribute(href)}">)
      when :script     then %(<script src="#{attribute(href)}"></script>)
      when :font       then %(url("#{href}"))
      else raise ArgumentError, "unknown asset kind #{kind.inspect}"
      end
    end

    # Escapes exactly what Phlex escapes in an attribute, so a Phlex host
    # and a heredoc host render the same tag.
    def attribute(value)
      value.to_s.gsub('"', "&quot;")
    end

    # Rewrites each relative url() in `css` (resolved against `dir`) to what
    # the block returns for that file. A target that is not a file is left
    # as written.
    def rewrite_css_urls(css, dir)
      css.gsub(CSS_URL) do
        original = Regexp.last_match(0)
        target = Regexp.last_match(2).strip
        next original if target.match?(CSS_URL_KEEP)

        file = File.expand_path(target.sub(/[?#].*\z/, ""), dir)
        File.file?(file) ? %(url("#{yield(file)}")) : original
      end
    end

    class Served
      def ref(path, kind)
        Delivery.tag(href(path), kind)
      end

      private

      def href(path)
        return path if path.to_s.match?(SERVED) || !Delivery.local_file(path)

        "/sw-asset/#{ComponentAssets.register_file(path)}/#{File.basename(path)}"
      end
    end

    class Inline
      def ref(path, kind)
        file = Delivery.local_file(path)
        return Delivery.tag(path, kind) unless file

        case kind
        when :stylesheet then "<style>#{stylesheet(file)}</style>"
        when :script     then "<script>#{File.read(file)}</script>"
        else Delivery.tag(data_uri(file), kind)
        end
      end

      private

      def stylesheet(path)
        Delivery.rewrite_css_urls(File.read(path), File.dirname(path)) { |file| data_uri(file) }
      end

      def data_uri(path)
        "data:#{Delivery.mime_type(path)};base64,#{Base64.strict_encode64(File.binread(path))}"
      end
    end

    class Copied
      DIR = "sw-assets"

      # @param root [String] the build's output directory; files land in root/sw-assets
      def initialize(root)
        @root = root
      end

      def ref(path, kind)
        file = Delivery.local_file(path)
        Delivery.tag(file ? copy(file) : path, kind)
      end

      private

      # Copies `path` (and, for a stylesheet, every file its relative url()s
      # name, as siblings) and returns its href relative to the root.
      def copy(path)
        name = "#{Digest::SHA256.hexdigest(path)[0, 8]}-#{File.basename(path)}"
        dest = File.join(@root, DIR, name)
        FileUtils.mkdir_p(File.dirname(dest))
        if File.extname(path) == ".css"
          css = Delivery.rewrite_css_urls(File.read(path), File.dirname(path)) { |file| File.basename(copy(file)) }
          File.write(dest, css)
        else
          FileUtils.cp(path, dest)
        end
        "#{DIR}/#{name}"
      end
    end
  end
end
