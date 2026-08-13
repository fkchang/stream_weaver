# frozen_string_literal: true

require 'cgi'
require 'json'
require 'socket'
require 'sinatra/base'
require 'stream_weaver/app'
require 'stream_weaver/views'
require 'stream_weaver/adapter/alpinejs'
require 'stream_weaver/canvas/doc_store'
require 'stream_weaver/page_shell'
require 'stream_weaver/export/html_exporter'

module StreamWeaver
  module Canvas
    class Reader < Sinatra::Base
      class NoFilesError < StandardError; end

      class FileList
        attr_reader :files, :history_roots

        def self.build(args, history_roots: [])
          files = args.flat_map do |arg|
            if File.directory?(arg)
              Dir.glob(File.join(arg, '*.rb')).sort
            elsif File.exist?(arg) && arg.end_with?('.rb')
              [File.expand_path(arg)]
            else
              []
            end
          end.uniq

          raise NoFilesError, "No .rb files found in: #{args.join(', ')}" if files.empty?

          new(files, history_roots: history_roots)
        end

        def initialize(files, history_roots: [])
          @files = files
          @history_roots = history_roots.map { |p| File.expand_path(p) }
        end

        def groups
          @files.group_by { |f| File.dirname(f) }
        end

        def indexed_groups
          @indexed_groups ||= @files.each_with_index.group_by { |f, _| File.dirname(f) }
        end

        # True when dir is the same as a history root or sits underneath one.
        def history_dir?(dir)
          @history_roots.any? { |r| dir == r || dir.start_with?(r + '/') }
        end

        # Sidebar splits: docs (explicit args) render above, history (auto-collected
        # snapshots from ~/.streamweaver/history/) renders below collapsed.
        def docs_groups
          indexed_groups.reject { |dir, _| history_dir?(dir) }
        end

        def history_groups
          indexed_groups.select { |dir, _| history_dir?(dir) }
        end

        # Array#[] wraps on negative indices and nil.to_i is 0 -- neither is a
        # valid file reference, so this refuses both centrally rather than
        # every caller re-deriving the same guard (and GET / not bothering to).
        def at(index)
          @files[index] if index.is_a?(Integer) && index >= 0
        end

        def size
          @files.size
        end
      end

      MERMAID_ZOOM_JS = File.read(File.expand_path('../assets/js/sw-mermaid-zoom.js', __dir__))
      private_constant :MERMAID_ZOOM_JS

      configure do
        set :views,   File.expand_path('../views/canvas', __dir__)
        set :bind,    '127.0.0.1'
        set :server,  :puma
        set :logging, false
      end

      # What Reader.render_doc hands the layout template: the rendered HTML
      # plus the theme/layout/CSS the DSL declared for itself, which the shell
      # needs for the <body> class and the user-CSS <style> tags.
      Doc = Struct.new(:html, :theme, :layout, :inline_stylesheets, keyword_init: true)

      class << self
        attr_reader :file_list, :default_theme, :default_layout

        def configure_files!(list)
          @file_list = list
        end

        # Fallback theme/layout for files that don't declare their own
        # (`canvas-read --theme=doc --layout=fluid`). Precedence is
        # DSL use_theme > CLI flag > :default/:fluid.
        def configure_defaults!(theme: nil, layout: nil)
          @default_theme  = theme&.to_sym
          @default_layout = layout&.to_sym
        end

        # render_doc and GET /export both need these; a single source of
        # truth is what makes "the download matches what's on screen" true
        # rather than aspirational -- two independent `|| :fluid`s could
        # silently drift.
        def fallback_theme
          default_theme || :default
        end

        def fallback_layout
          default_layout || :fluid
        end

        def find_available_port(start = 4800)
          port = start
          loop do
            TCPServer.new('127.0.0.1', port).close
            return port
          rescue Errno::EADDRINUSE
            port += 1
            raise "No available port found starting from #{start}" if port > start + 100
          end
        end
      end

      get '/health' do
        'ok'
      end

      get '/' do
        return redirect '/?file=0' unless params.key?('file')

        index = params[:file].to_i
        list  = self.class.file_list
        path  = list&.at(index)
        halt 404, 'File not found' unless path

        dsl = File.read(path)
        @doc             = Reader.render_doc(dsl, path: path)
        @file_list       = list
        @current_index   = index
        @current_file    = path
        @mermaid_zoom_js = MERMAID_ZOOM_JS
        erb :reader_layout, layout: false
      end

      # Download the currently-viewed file as a standalone HTML document.
      # Same ?file=N index convention as GET /, and the same theme/layout
      # fallbacks render_doc uses (fallback_theme/fallback_layout), so the
      # download matches what's on screen.
      #
      # Failures answer text/plain with a status, never a partial document:
      # a half-written .html landing in ~/Downloads looks like a success.
      # content_type is set to :text up front for exactly that reason --
      # halt'ing after a `content_type :html` would still serve the error
      # body as HTML. The export link itself must never carry a `download`
      # attribute, or the browser saves an error body as a mystery file
      # instead of showing it (see reader_layout.erb).
      # ?offline=1 inlines mermaid's own library instead of referencing its
      # CDN (stream_weaver-dnq), so a diagram renders in a viewer whose CSP
      # blocks external scripts entirely (SharePoint's HTML preview, etc.).
      # Needs network access at export time; a fetch failure there is a 502
      # (this server tried an upstream and it failed), distinct from the
      # 422s below for bad input.
      get '/export' do
        content_type :text
        path = self.class.file_list&.at(params[:file].to_i)
        halt 404, 'File not found' unless path

        html = begin
          StreamWeaver::Export::HtmlExporter.from_dsl_file(
            path,
            theme:  self.class.fallback_theme,
            layout: self.class.fallback_layout
          ).to_html(offline: params[:offline] == '1')
        rescue StreamWeaver::Export::InvalidDslError => e
          halt 422, "Export failed: #{e.message}"
        rescue StreamWeaver::Export::OfflineAssetError => e
          halt 502, "Export failed: #{e.message}"
        rescue ScriptError, StandardError => e
          # A DSL that fails to eval is bad input, not an exporter failure --
          # same 422 GET / gives the equivalent case (its red error box).
          halt 422, "Export failed: #{e.message}"
        end

        content_type :html
        headers['Content-Disposition'] =
          %(attachment; filename="#{StreamWeaver::Export::HtmlExporter.export_filename(path)}")
        html
      end

      # Promote a history snapshot to a persistent canvas doc (Tier 2).
      # Body: {"file": <integer-index>, "name": "<doc-name>"}.
      # Mirrors BridgeServer's /canvas/:name/save-doc contract: 200 on success,
      # 422 on bad index / bad name, 404 when no list configured, 500 otherwise.
      post '/save-doc' do
        content_type :json
        list = self.class.file_list
        halt 404, { ok: false, error: 'No file list configured' }.to_json unless list

        body  = JSON.parse(request.body.read, symbolize_names: true) rescue {}
        index = body[:file]
        name  = body[:name]

        # FileList#at already refuses non-Integer/negative indices; File.exist?
        # covers the case an in-range index still points at a file that's
        # since been deleted out from under us.
        file_path = list.at(index)
        unless file_path && File.exist?(file_path)
          halt 422, { ok: false, error: "File index out of range: #{index.inspect}" }.to_json
        end

        # No DocStore.dsl_with_metadata call here, unlike BridgeServer's
        # save-doc route: this promotes a history snapshot, and snapshots are
        # written by `canvas-push` (CLI.record_push_history), which never sees
        # the bridge session's theme/layout. There is nothing to inject.
        # Snapshots whose DSL doesn't declare `use_theme` itself keep rendering
        # with canvas-read's default -- accepted limitation (stream_weaver-csf).
        dsl = File.read(file_path)
        begin
          saved_path = StreamWeaver::Canvas::DocStore.save(name, dsl)
          { ok: true, path: saved_path }.to_json
        rescue ArgumentError => e
          halt 422, { ok: false, error: e.message }.to_json
        rescue StandardError => e
          halt 500, { ok: false, error: e.message }.to_json
        end
      end

      # Evaluates `dsl` and returns a Doc carrying the rendered HTML plus the
      # theme/layout/inline CSS the DSL declared for itself -- the reader shell
      # needs all four, and render_dsl's HTML-only return threw the rest away
      # (stream_weaver-csf).
      #
      # Caveat: rendering goes through AppContentView, which does not evaluate
      # exclusive-layout render blocks or layout slots (AppView-only concepts).
      # So `layout` here only reaches body-class/CSS-selector level layout --
      # a known, accepted gap, not something the reader can close.
      #
      # `mode: :websocket` is kept for component-markup parity with the canvas
      # (some components render differently in websocket mode). The reader's
      # <head> deliberately does NOT use adapter.cdn_scripts, which would drag
      # in a connect attempt to a /canvas/reader/ws endpoint that doesn't exist.
      #
      # @param path [String, nil] source file, passed through to instance_eval
      #   so a DSL error names the actual file/line instead of "(eval)".
      def self.render_doc(dsl, path: nil)
        theme  = fallback_theme
        layout = fallback_layout
        mini_app = StreamWeaver::App.new('reader', theme: theme, layout: layout)
        mini_app.instance_eval(dsl, path.to_s, 1)
        adapter = StreamWeaver::Adapter::AlpineJS.new(
          url_prefix: '/canvas/reader',
          mode: :websocket
        )
        Doc.new(
          html: StreamWeaver::Views::AppContentView.new(mini_app, {}, adapter, false).call,
          theme: mini_app.theme,
          layout: mini_app.layout,
          inline_stylesheets: mini_app.inline_stylesheets
        )
      rescue ScriptError, StandardError => e
        Doc.new(
          html: "<div style='color:red;padding:1rem;font-family:monospace'>" \
                "<strong>DSL error:</strong> #{CGI.escapeHTML(e.message)}</div>",
          theme: theme,
          layout: layout,
          inline_stylesheets: []
        )
      end

      def self.render_dsl(dsl)
        render_doc(dsl).html
      end
    end
  end
end
