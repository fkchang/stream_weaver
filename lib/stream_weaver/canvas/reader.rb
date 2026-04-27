# frozen_string_literal: true

require 'sinatra/base'
require 'fileutils'

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
    end
  end
end
