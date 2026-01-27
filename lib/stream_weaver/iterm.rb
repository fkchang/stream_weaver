# frozen_string_literal: true

require 'open3'

module StreamWeaver
  # iTerm2 AppleScript integration for panel workflow
  class ITerm
    class << self
      # Check if iTerm2 is the current terminal
      def available?
        return false unless darwin?

        # Check if iTerm2 is running
        script = 'tell application "System Events" to (name of processes) contains "iTerm2"'
        stdout, _status = Open3.capture2("osascript", "-e", script)
        stdout.strip == "true"
      end

      # Split current iTerm2 pane vertically and open URL in the new pane
      # Returns: :browser (iTerm browser), :external (system browser), or false (failed)
      def split_vertical_with_url(url)
        return false unless available?

        # Try iTerm2 browser profile first, fall back to external browser
        script = <<~APPLESCRIPT
          tell application "iTerm2"
            tell current session of current tab of current window
              -- Try to split with browser profile (iTerm2 3.5+)
              try
                set newSession to (split vertically with profile "Browser")
                tell newSession
                  write text "#{url}"
                end tell
                return "browser"
              on error errMsg
                -- No browser profile, split with terminal and open external browser
                set newSession to (split vertically with default profile)
                tell newSession
                  write text "echo ''; echo '  StreamWeaver Canvas'; echo '  #{url}'; echo ''; echo '  (opened in browser)'; echo ''"
                end tell
                return "external"
              end try
            end tell
          end tell
        APPLESCRIPT

        stdout, status = Open3.capture2("osascript", stdin_data: script)
        return false unless status.success?

        result = stdout.strip

        # If we used external mode, also open the browser
        if result == "external"
          system("open", url)
        end

        result.to_sym
      end

      # Just split the pane and run a command (no browser)
      def split_vertical_with_command(command)
        return false unless available?

        script = <<~APPLESCRIPT
          tell application "iTerm2"
            tell current session of current tab of current window
              set newSession to (split vertically with default profile)
              tell newSession
                write text "#{command}"
              end tell
            end tell
          end tell
        APPLESCRIPT

        _stdout, status = Open3.capture2("osascript", stdin_data: script)
        status.success?
      end

      # Open URL in default browser (fallback for non-iTerm2)
      def open_browser(url)
        case RbConfig::CONFIG['host_os']
        when /darwin|mac os/
          system("open", url)
        when /linux/
          system("xdg-open", url)
        when /mswin|mingw|cygwin/
          system("start", url)
        else
          puts "Please open: #{url}"
          false
        end
      end

      private

      def darwin?
        RbConfig::CONFIG['host_os'] =~ /darwin|mac os/
      end
    end
  end
end
