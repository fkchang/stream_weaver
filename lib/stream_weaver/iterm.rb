# frozen_string_literal: true

require 'open3'
require 'timeout'

module StreamWeaver
  # iTerm2 AppleScript integration for panel workflow
  class ITerm
    class << self
      # Check if iTerm2 is the current terminal
      def available?
        return false unless darwin?

        # Check if iTerm2 is running (with timeout to prevent hanging)
        begin
          Timeout.timeout(3) do
            script = 'tell application "System Events" to (name of processes) contains "iTerm2"'
            stdout, _status = Open3.capture2("osascript", "-e", script)
            stdout.strip == "true"
          end
        rescue Timeout::Error
          false
        end
      end

      # Get current session identifier from environment
      # iTerm2 sets ITERM_SESSION_ID like "w0t0p0:GUID"
      def current_session_id
        ENV['ITERM_SESSION_ID']
      end

      # Split the calling iTerm2 pane vertically and optionally open URL in browser
      # @param url [String] The URL to display/open
      # @param open_browser [Boolean] Whether to open the URL in system browser (default: true)
      # Returns: Hash with :type (:external or false) and :pane_id
      #
      # NOTE: Previously attempted to use iTerm's Web Browser profile with AppleScript
      # keystrokes to type the URL, but this was unreliable - keystrokes would go to
      # the wrong window causing hangs. Now just opens in external browser.
      def split_vertical_with_url(url, open_browser: true)
        return { type: false, pane_id: nil } unless available?

        system("open", url) if open_browser
        { type: :external, pane_id: nil }
      end

      # Close an iTerm2 pane by its unique ID
      # @param pane_id [String] The unique ID of the pane to close
      # @return [Boolean] true if closed successfully
      def close_pane(pane_id)
        return false unless available?
        return false unless pane_id

        script = <<~APPLESCRIPT
          tell application "iTerm2"
            repeat with aWindow in windows
              repeat with aTab in tabs of aWindow
                repeat with aSession in sessions of aTab
                  if unique ID of aSession is "#{escape_for_applescript(pane_id)}" then
                    tell aSession to close
                    return "closed"
                  end if
                end repeat
              end repeat
            end repeat
            return "not_found"
          end tell
        APPLESCRIPT

        begin
          Timeout.timeout(5) do
            stdout, status = Open3.capture2("osascript", stdin_data: script)
            status.success? && stdout.strip == "closed"
          end
        rescue Timeout::Error
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

        begin
          Timeout.timeout(10) do
            _stdout, status = Open3.capture2("osascript", stdin_data: script)
            status.success?
          end
        rescue Timeout::Error
          false
        end
      end

      private

      # Escape string for safe embedding in AppleScript
      def escape_for_applescript(str)
        str.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
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
