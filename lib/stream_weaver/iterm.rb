# frozen_string_literal: true

module StreamWeaver
  # iTerm2 AppleScript integration for panel workflow
  class ITerm
    class << self
      # Check if iTerm2 is the current terminal
      def available?
        return false unless darwin?

        # Check if iTerm2 is running and we're in it
        script = 'tell application "System Events" to (name of processes) contains "iTerm2"'
        result = `osascript -e '#{script}' 2>/dev/null`.strip
        result == "true"
      end

      # Split current iTerm2 pane vertically and run a command in the new pane
      def split_vertical_with_command(command)
        return false unless available?

        script = <<~APPLESCRIPT
          tell application "iTerm2"
            tell current session of current tab of current window
              set newSession to (split vertically with default profile)
              tell newSession
                write text "#{escape_for_applescript(command)}"
              end tell
            end tell
          end tell
        APPLESCRIPT

        system("osascript", "-e", script)
      end

      # Split and open a URL in iTerm2's built-in browser
      # Note: This requires iTerm2 3.5+ with browser profiles enabled
      def split_vertical_with_browser(url)
        return false unless available?

        # First try the browser profile approach (iTerm2 3.5+)
        # If that fails, fall back to opening in default browser
        script = <<~APPLESCRIPT
          tell application "iTerm2"
            tell current session of current tab of current window
              -- Try to split with a browser profile
              try
                set newSession to (split vertically with profile "Browser")
                tell newSession
                  write text "#{escape_for_applescript(url)}"
                end tell
                return "browser"
              on error
                -- Fall back to opening URL in default browser
                -- and creating a new terminal pane that shows info
                set newSession to (split vertically with default profile)
                tell newSession
                  write text "echo 'StreamWeaver Canvas opened in browser'; echo '#{escape_for_applescript(url)}'; echo ''; echo 'Press Ctrl+C to close this pane'"
                end tell
                do shell script "open '#{escape_for_applescript(url)}'"
                return "external"
              end try
            end tell
          end tell
        APPLESCRIPT

        result = `osascript -e '#{script}' 2>/dev/null`.strip
        result == "browser" || result == "external"
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

      def escape_for_applescript(str)
        str.gsub('\\', '\\\\\\\\').gsub('"', '\\"').gsub("'", "'\\''")
      end
    end
  end
end
