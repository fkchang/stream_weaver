# frozen_string_literal: true

require 'cgi'
require 'json'
require 'socket'
require 'sinatra/base'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/doc_store'

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

        def at(index)
          @files[index]
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

      class << self
        attr_reader :file_list

        def configure_files!(list)
          @file_list = list
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
        @content_html    = Reader.render_dsl(dsl)
        @file_list       = list
        @current_index   = index
        @current_file    = path
        @sw_styles       = StreamWeaver::Canvas::BridgeServer::SW_STYLES
        @mermaid_zoom_js = MERMAID_ZOOM_JS
        erb :reader_layout, layout: false
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

        file_path = list.at(index.to_i) if index.is_a?(Integer) || index.respond_to?(:to_i)
        unless file_path && File.exist?(file_path)
          halt 422, { ok: false, error: "File index out of range: #{index.inspect}" }.to_json
        end

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

      def self.render_dsl(dsl)
        mini_app = StreamWeaver::App.new('reader')
        mini_app.instance_eval(dsl)
        adapter = StreamWeaver::Adapter::AlpineJS.new(
          url_prefix: '/canvas/reader',
          mode: :websocket
        )
        StreamWeaver::Views::AppContentView.new(mini_app, {}, adapter, false).call
      rescue ScriptError, StandardError => e
        "<div style='color:red;padding:1rem;font-family:monospace'>" \
          "<strong>DSL error:</strong> #{CGI.escapeHTML(e.message)}</div>"
      end
    end
  end
end
