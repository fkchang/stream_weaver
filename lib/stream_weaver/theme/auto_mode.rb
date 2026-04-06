# frozen_string_literal: true

module StreamWeaver
  class Theme
    # JavaScript generation for auto-mode theme toggle.
    # Manages data-theme attribute on <html>, meta theme-color,
    # and localStorage persistence.
    #
    # Auto-mode is opt-in: it does not activate unless
    # theme_toggle(mode: :auto) is called in the app.
    #
    # sw- CSS prefix convention:
    #   Toggle button: sw-theme-toggle
    #   State attribute: data-sw-theme="dark|light|auto"
    module AutoMode
      # Generate the inline JavaScript for auto-mode detection and toggling.
      # This script runs immediately (no DOMContentLoaded wait) to prevent
      # flash of wrong theme.
      #
      # @param meta_colors [Hash] theme-color values for light/dark
      # @return [String] JavaScript code
      def self.inline_script(meta_colors: { light: "#f8f8f8", dark: "#1a1a1a" })
        <<~JS
          (function() {
            // sw-theme auto-mode: follows OS prefers-color-scheme with localStorage override
            var STORAGE_KEY = 'sw-theme-preference';
            var META_COLORS = #{meta_colors.to_json};

            function getEffectiveTheme() {
              var stored = localStorage.getItem(STORAGE_KEY);
              if (stored === 'dark' || stored === 'light') return stored;
              // auto or no preference: follow OS
              return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            }

            function getStoredPreference() {
              return localStorage.getItem(STORAGE_KEY) || 'auto';
            }

            function applyTheme(effective) {
              var html = document.documentElement;
              html.classList.toggle('dark', effective === 'dark');
              html.setAttribute('data-sw-theme', effective);

              // Update meta theme-color
              var meta = document.querySelector('meta[name="theme-color"]');
              if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'theme-color';
                document.head.appendChild(meta);
              }
              meta.content = META_COLORS[effective] || META_COLORS.light;
            }

            // Apply immediately to prevent FOUC
            applyTheme(getEffectiveTheme());

            // Listen for OS preference changes (only matters in auto mode)
            var mql = window.matchMedia('(prefers-color-scheme: dark)');
            mql.addEventListener('change', function() {
              if (getStoredPreference() === 'auto') {
                applyTheme(getEffectiveTheme());
              }
            });

            // Global toggle function, callable from Alpine.js or anywhere
            window.swToggleTheme = function(mode) {
              if (mode === 'auto') {
                localStorage.setItem(STORAGE_KEY, 'auto');
              } else if (mode === 'dark' || mode === 'light') {
                localStorage.setItem(STORAGE_KEY, mode);
              } else {
                // Cycle: auto -> light -> dark -> auto
                var current = getStoredPreference();
                var next = current === 'auto' ? 'light' : current === 'light' ? 'dark' : 'auto';
                localStorage.setItem(STORAGE_KEY, next);
              }
              applyTheme(getEffectiveTheme());
              return getStoredPreference();
            };

            // Query current state
            window.swGetTheme = function() {
              return {
                preference: getStoredPreference(),
                effective: getEffectiveTheme()
              };
            };
          })();
        JS
      end

      # Generate the Alpine.js x-data for the theme toggle button
      #
      # @return [String] Alpine.js data expression
      def self.alpine_data
        <<~JS.gsub(/\s+/, " ").strip
          {
            preference: (localStorage.getItem('sw-theme-preference') || 'auto'),
            get effective() {
              if (this.preference === 'dark' || this.preference === 'light') return this.preference;
              return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
            },
            toggle() {
              this.preference = swToggleTheme();
            },
            setMode(mode) {
              this.preference = swToggleTheme(mode);
            }
          }
        JS
      end
    end
  end
end
