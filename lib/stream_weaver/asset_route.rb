# frozen_string_literal: true

require "digest"
require_relative "delivery"

module StreamWeaver
  # The /sw-asset route Delivery::Served points at, for every server that
  # renders pages in-process (the standalone server, the canvas bridge, the
  # reader): `register StreamWeaver::AssetRoute`.
  #
  # Only files whose absolute path was explicitly registered are served (no
  # traversal: the key is a hash of that path, never derived from the
  # request), and registration itself validated the path (App#local_asset,
  # the css_path/js_path/font macros, a theme's fonts:).
  module AssetRoute
    def self.registered(app)
      app.get "/sw-asset/:key/:filename" do
        abs_path = StreamWeaver::ComponentAssets.resolve_file(params[:key])
        halt 404 unless abs_path && File.exist?(abs_path)
        halt 404 unless File.basename(abs_path) == params[:filename]
        etag Digest::MD5.hexdigest("#{File.mtime(abs_path).to_i}-#{File.size(abs_path)}")
        content_type StreamWeaver::Delivery.mime_type(abs_path)
        File.binread(abs_path)
      end
    end
  end
end
