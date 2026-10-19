# frozen_string_literal: true

module StreamWeaver
  module Canvas
    # Which Host headers the canvas servers (the bridge on 4700 and the
    # reader) will answer. Loopback always; anything else only when named in
    # STREAMWEAVER_CANVAS_ALLOWED_HOSTS (comma separated), e.g.
    #
    #   STREAMWEAVER_CANVAS_ALLOWED_HOSTS=mac.tail1234.ts.net,mac,100.64.0.7
    #
    # The same entries (comma or newline separated, # comments) may live in
    # ~/.streamweaver/canvas_allowed_hosts (STREAMWEAVER_CANVAS_ALLOWED_HOSTS_FILE
    # overrides the path); the two are unioned. The file is what survives an
    # automatic bridge restart from a shell that does not have the variable.
    # Default empty = loopback only. Matching is exact on the host part
    # (port ignored); an empty Host and any wildcard entry never match, so a
    # typo cannot open the servers to everyone. Read from ENV on every call,
    # so the bridge and the reader cannot disagree about it.
    module AllowedHosts
      ENV_KEY  = 'STREAMWEAVER_CANVAS_ALLOWED_HOSTS'
      FILE_ENV_KEY = 'STREAMWEAVER_CANVAS_ALLOWED_HOSTS_FILE'
      DEFAULT_FILE = '~/.streamweaver/canvas_allowed_hosts'
      LOOPBACK = %w[127.0.0.1 localhost ::1].freeze

      module_function

      def file_path
        File.expand_path(ENV.fetch(FILE_ENV_KEY, DEFAULT_FILE))
      end

      def configured
        file = File.file?(file_path) ? File.read(file_path, encoding: 'UTF-8').scrub.gsub(/#.*$/, '') : ''
        "#{ENV.fetch(ENV_KEY, '')},#{file}".split(/[,\n]/).map { |h| host_part(h) }
                                           .reject { |h| h.empty? || h.match?(/[*\s\/]/) }.uniq
      rescue SystemCallError
        []
      end

      def all
        LOOPBACK + configured
      end

      # `header` is the raw Host header ("name", "name:port", "[::1]:4700").
      # The raw header, not Rack's request.host, which prefers
      # X-Forwarded-Host and so would let a client pick its own answer.
      def permitted?(header)
        host = host_part(header)
        !host.empty? && all.include?(host)
      end

      def host_part(header)
        value = header.to_s.strip.downcase
        return Regexp.last_match(1) if value =~ /\A\[([^\]]*)\](?::\d+)?\z/
        value.sub(/:\d+\z/, '')
      end
    end
  end
end
