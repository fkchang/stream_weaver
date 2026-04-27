# frozen_string_literal: true

require 'cgi'
require 'socket'
require 'sinatra/base'

module StreamWeaver
  module Canvas
    class Reader < Sinatra::Base
      class NoFilesError < StandardError; end

      class FileList
        attr_reader :files

        def self.build(args)
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

          new(files)
        end

        def initialize(files)
          @files = files
        end

        def groups
          @files.group_by { |f| File.dirname(f) }
        end

        def at(index)
          @files[index]
        end

        def size
          @files.size
        end
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
          end
        end
      end

      set :views, File.expand_path('../views/canvas', __dir__)

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
        @content_html  = Reader.render_dsl(dsl)
        @file_list     = list
        @current_index = index
        erb :reader_layout, layout: false
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
