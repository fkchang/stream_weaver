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

      # Get current session identifier from environment
      # iTerm2 sets ITERM_SESSION_ID like "w0t0p0:GUID"
      def current_session_id
        ENV['ITERM_SESSION_ID']
      end

      # Split the calling iTerm2 pane vertically and optionally open URL in browser
      # @param url [String] The URL to display/open
      # @param open_browser [Boolean] Whether to open the URL in system browser if iTerm browser fails (default: true)
      # Returns: :browser (iTerm2 browser), :terminal (fallback), or false (failed)
      def split_vertical_with_url(url, open_browser: true)
        return false unless available?

        debug = ENV['DEBUG_PANEL']

        session_id = current_session_id
        escaped_url = escape_for_applescript(url)

        $stderr.puts "[DEBUG iTerm] url: #{url.inspect}" if debug
        $stderr.puts "[DEBUG iTerm] escaped_url: #{escaped_url.inspect}" if debug
        $stderr.puts "[DEBUG iTerm] session_id: #{session_id.inspect}" if debug

        # Build AppleScript that targets the specific calling session
        script = if session_id
          build_targeted_split_script(session_id, escaped_url)
        else
          build_current_split_script(escaped_url)
        end

        $stderr.puts "[DEBUG iTerm] AppleScript length: #{script.length} chars" if debug
        if debug
          # Log the actual keystroke line from the script
          keystroke_line = script.lines.find { |l| l.include?('keystroke "http') }
          $stderr.puts "[DEBUG iTerm] Keystroke line: #{keystroke_line&.strip.inspect}"
        end

        stdout, status = Open3.capture2("osascript", stdin_data: script)

        $stderr.puts "[DEBUG iTerm] osascript status: #{status.success?}" if debug
        $stderr.puts "[DEBUG iTerm] osascript stdout: #{stdout.inspect}" if debug

        return false unless status.success?

        result = stdout.strip

        case result
        when "browser"
          :browser
        when "terminal"
          # Open external browser as fallback if requested
          system("open", url) if open_browser
          :terminal
        else
          false
        end
      end

      # Just split the pane and run a command (no browser)
      def split_vertical_with_command(command)
        return false unless available?

        session_id = current_session_id
        escaped_command = escape_for_applescript(command)

        script = if session_id
          build_targeted_command_script(session_id, escaped_command)
        else
          build_current_command_script(escaped_command)
        end

        _stdout, status = Open3.capture2("osascript", stdin_data: script)
        status.success?
      end

      private

      # Escape string for safe embedding in AppleScript
      def escape_for_applescript(str)
        str.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
      end

      # Build AppleScript that targets a specific session by ITERM_SESSION_ID
      def build_targeted_split_script(session_id, escaped_url)
        # ITERM_SESSION_ID format: "w0t0p0:GUID" - we need the GUID part
        guid = session_id.split(':').last

        <<~APPLESCRIPT
          tell application "iTerm2"
            -- Find the session with the matching ID
            repeat with aWindow in windows
              repeat with aTab in tabs of aWindow
                repeat with aSession in sessions of aTab
                  if unique ID of aSession contains "#{guid}" then
                    tell aSession
                      -- Try Web Browser profile first
                      try
                        set newSession to (split vertically with profile "Web Browser")
                        -- Select the new session to ensure it has focus
                        select newSession
                        delay 1.0
                        -- Use keyboard to navigate
                        -- Press Escape first to dismiss any autocomplete/suggestions
                        tell application "System Events"
                          tell process "iTerm2"
                            key code 53 -- Escape
                            delay 0.2
                            keystroke "l" using command down
                            delay 0.3
                            key code 53 -- Escape again to dismiss autocomplete dropdown
                            delay 0.2
                            keystroke "#{escaped_url}"
                            delay 0.3
                            keystroke return
                          end tell
                        end tell
                        return "browser"
                      on error errMsg
                        -- Fall back to terminal with info
                        set newSession to (split vertically with default profile)
                        tell newSession
                          write text "clear; echo ''; echo '  StreamWeaver Canvas'; echo '  #{escaped_url}'; echo ''"
                        end tell
                        return "terminal"
                      end try
                    end tell
                  end if
                end repeat
              end repeat
            end repeat
            return "session_not_found"
          end tell
        APPLESCRIPT
      end

      # Fallback: split current session (when ITERM_SESSION_ID not available)
      def build_current_split_script(escaped_url)
        <<~APPLESCRIPT
          tell application "iTerm2"
            tell current session of current tab of current window
              -- Try Web Browser profile first
              try
                set newSession to (split vertically with profile "Web Browser")
                -- Select the new session to ensure it has focus
                select newSession
                delay 1.0
                -- Use keyboard to navigate
                -- Press Escape first to dismiss any autocomplete/suggestions
                tell application "System Events"
                  tell process "iTerm2"
                    key code 53 -- Escape
                    delay 0.2
                    keystroke "l" using command down
                    delay 0.3
                    key code 53 -- Escape again to dismiss autocomplete dropdown
                    delay 0.2
                    keystroke "#{escaped_url}"
                    delay 0.3
                    keystroke return
                  end tell
                end tell
                return "browser"
              on error errMsg
                -- Fall back to terminal with info
                set newSession to (split vertically with default profile)
                tell newSession
                  write text "clear; echo ''; echo '  StreamWeaver Canvas'; echo '  #{escaped_url}'; echo ''"
                end tell
                return "terminal"
              end try
            end tell
          end tell
        APPLESCRIPT
      end

      # Build AppleScript for command execution targeting specific session
      def build_targeted_command_script(session_id, escaped_command)
        guid = session_id.split(':').last

        <<~APPLESCRIPT
          tell application "iTerm2"
            repeat with aWindow in windows
              repeat with aTab in tabs of aWindow
                repeat with aSession in sessions of aTab
                  if unique ID of aSession contains "#{guid}" then
                    tell aSession
                      set newSession to (split vertically with default profile)
                      tell newSession
                        write text "#{escaped_command}"
                      end tell
                    end tell
                    return "ok"
                  end if
                end repeat
              end repeat
            end repeat
            return "session_not_found"
          end tell
        APPLESCRIPT
      end

      # Fallback: command in current session
      def build_current_command_script(escaped_command)
        <<~APPLESCRIPT
          tell application "iTerm2"
            tell current session of current tab of current window
              set newSession to (split vertically with default profile)
              tell newSession
                write text "#{escaped_command}"
              end tell
            end tell
          end tell
        APPLESCRIPT
      end

      def darwin?
        RbConfig::CONFIG['host_os'] =~ /darwin|mac os/
      end
    end
  end
end
