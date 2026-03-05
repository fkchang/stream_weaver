# frozen_string_literal: true

require 'fileutils'

module StreamWeaver
  # Portfile-based discovery for running StreamWeaver apps.
  # Apps write a portfile on startup; feed scripts read them to connect.
  #
  # Location: ~/.streamweaver/apps/<sanitized_name>.port
  # Format:   url=http://127.0.0.1:4567\npid=12345\nname=My App\n
  module Portfile
    DIR = File.expand_path("~/.streamweaver/apps")

    def self.sanitize(name)
      name.downcase.gsub(/[^a-z0-9_-]/, "_")
    end

    def self.path_for(name)
      File.join(DIR, "#{sanitize(name)}.port")
    end

    def self.write(name, url:, pid:)
      FileUtils.mkdir_p(DIR)
      File.write(path_for(name), "url=#{url}\npid=#{pid}\nname=#{name}\n")
    end

    def self.delete(name)
      path = path_for(name)
      FileUtils.rm_f(path)
    end

    def self.read(name)
      path = path_for(name)
      raise Error, "No portfile for '#{name}' at #{path}. Is the app running?" unless File.exist?(path)
      parse_and_validate(path, name)
    end

    def self.discover_single
      FileUtils.mkdir_p(DIR)
      clean_stale!
      files = Dir.glob(File.join(DIR, "*.port"))
      case files.size
      when 0 then raise Error, "No StreamWeaver apps running (no portfiles in #{DIR})"
      when 1 then parse_and_validate(files.first)
      else raise Error, "Multiple apps running. Specify name: StreamWeaver.connect('App Name')"
      end
    end

    def self.clean_stale!
      return unless Dir.exist?(DIR)
      Dir.glob(File.join(DIR, "*.port")).each do |path|
        pid = File.read(path)[/^pid=(\d+)$/, 1]&.to_i
        next unless pid
        FileUtils.rm_f(path) unless process_alive?(pid)
      end
    end

    def self.process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def self.parse_and_validate(path, display_name = nil)
      data = File.read(path)
      url = data[/^url=(.+)$/, 1]
      pid = data[/^pid=(\d+)$/, 1]&.to_i
      display_name ||= data[/^name=(.+)$/, 1] || File.basename(path, ".port")

      if pid && !process_alive?(pid)
        FileUtils.rm_f(path)
        raise Error, "App '#{display_name}' is no longer running (stale portfile cleaned up)"
      end

      url or raise Error, "Malformed portfile at #{path}"
    end
  end
end
