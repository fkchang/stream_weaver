# frozen_string_literal: true

require 'cgi'
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
