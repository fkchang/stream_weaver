# frozen_string_literal: true

require "digest"
require_relative "delivery"

module StreamWeaver
  # The /sw-asset route Delivery::Served points at, for every server that
  # renders pages in-process (the standalone server, Service, the canvas
  # bridge, the reader): `register StreamWeaver::AssetRoute`.
  #
  # Only files whose absolute path was registered are served (no traversal:
  # the key is a hash of that path, never derived from the request). The
  # registered set is whatever an author handed to a Delivery or to
  # App#local_asset (css_path/js_path/font macros, a theme's fonts:,
  # stylesheets:): the DSL is trusted code, so registration is not a
  # sandbox. local_asset alone checks the app's asset dirs.
  module AssetRoute
    def self.registered(app)
      app.get "/sw-asset/:key/:filename" do
        abs_path = StreamWeaver::ComponentAssets.resolve_file(params[:key])
        halt 404 unless abs_path && File.file?(abs_path)
        halt 404 unless File.basename(abs_path) == params[:filename]
        etag Digest::MD5.hexdigest("#{File.mtime(abs_path).to_i}-#{File.size(abs_path)}")
        content_type StreamWeaver::Delivery.mime_type(abs_path)
        headers 'X-Content-Type-Options' => 'nosniff'
        if File.extname(abs_path) == ".css"
          # A relative url() in a served stylesheet would resolve under
          # /sw-asset/<key>/, which no route answers: point each file it
          # names at its own /sw-asset URL instead.
          StreamWeaver::Delivery.rewrite_css_urls(File.read(abs_path), File.dirname(abs_path)) do |file|
            StreamWeaver::ComponentAssets.url(file)
          end
        else
          File.binread(abs_path)
        end
      end
    end
  end
end
