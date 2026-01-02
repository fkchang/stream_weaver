# frozen_string_literal: true

module StreamWeaver
  # Shared utility methods used across CLI, Admin, and other modules
  module Utils
    extend self

    # Format seconds as human-readable duration
    # @param seconds [Integer] Number of seconds
    # @return [String] Human-readable duration (e.g., "5m ago", "2h ago")
    def format_duration(seconds)
      return "just now" if seconds < 5

      case seconds
      when ...60    then "#{seconds}s ago"
      when ...3600  then "#{seconds / 60}m ago"
      when ...86400 then "#{seconds / 3600}h ago"
      else               "#{seconds / 86400}d ago"
      end
    end

    # Truncate string with ellipsis
    # @param str [String] String to truncate
    # @param max_length [Integer] Maximum length including ellipsis
    # @return [String] Truncated string
    def truncate(str, max_length)
      return str if str.length <= max_length
      str[0..max_length - 4] + "..."
    end
  end
end
