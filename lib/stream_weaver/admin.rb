# frozen_string_literal: true

module StreamWeaver
  # Admin dashboard for managing StreamWeaver service and apps
  # Launch with: streamweaver admin
  class Admin
    def self.create_app
      App.new(
        "StreamWeaver Admin",
        layout: :wide,
        theme: :dashboard
      ) do
        # Get current apps from service
        apps_data = Service.apps.map do |id, entry|
          {
            id: id,
            name: entry[:name],
            title: entry[:app].title,
            path: entry[:path],
            file: File.basename(entry[:path]),
            loaded_at: entry[:loaded_at],
            last_accessed: entry[:last_accessed],
            age_seconds: (Time.now - entry[:loaded_at]).to_i,
            idle_seconds: (Time.now - entry[:last_accessed]).to_i
          }
        end

        # Header
        hstack spacing: :md, align: :center do
          header1 "StreamWeaver Admin"
          div style: "flex: 1;" do end  # Spacer
          status_badge :success, "Running on port #{Service.settings.port}"
        end

        div style: "margin-top: 1rem;" do end

        # Stats row
        hstack spacing: :lg do
          card do
            div style: "text-align: center;" do
              div style: "font-size: 2rem; font-weight: bold; color: var(--sw-color-primary);" do
                text apps_data.length.to_s
              end
              text "Apps Loaded"
            end
          end

          card do
            div style: "text-align: center;" do
              pid_info = Service.read_pid_file
              div style: "font-size: 2rem; font-weight: bold; color: var(--sw-color-primary);" do
                text pid_info ? pid_info[:pid].to_s : "N/A"
              end
              text "Service PID"
            end
          end

          card do
            div style: "text-align: center;" do
              div style: "font-size: 2rem; font-weight: bold; color: var(--sw-color-primary);" do
                text Service.settings.port.to_s
              end
              text "Port"
            end
          end
        end

        div style: "margin-top: 1.5rem;" do end

        # Action buttons
        hstack spacing: :sm do
          button "🔄 Refresh", style: :secondary do |s|
            # Just trigger a re-render by touching state
            s[:_refresh] = Time.now.to_i
          end

          button "🗑️ Clear All Apps", style: :secondary do |s|
            Service.clear_apps
            s[:_refresh] = Time.now.to_i
          end
        end

        div style: "margin-top: 1.5rem;" do end

        # Apps list
        if apps_data.empty?
          card do
            div style: "text-align: center; padding: 2rem; color: #666;" do
              text "No apps loaded"
              div style: "margin-top: 0.5rem; font-size: 0.9rem;" do
                text "Run an app with: streamweaver <file.rb>"
              end
            end
          end
        else
          header3 "Loaded Apps"

          apps_data.each do |app|
            card style: "margin-bottom: 1rem;" do
              hstack spacing: :md, align: :center do
                # App icon and name
                div style: "flex: 1;" do
                  hstack spacing: :sm, align: :center do
                    div style: "font-size: 1.5rem;" do
                      text "📱"
                    end
                    div do
                      div style: "font-weight: 600; font-size: 1.1rem;" do
                        text app[:name]
                      end
                      div style: "font-size: 0.85rem; color: #666; font-family: monospace;" do
                        text "#{app[:file]} • #{app[:id]}"
                      end
                    end
                  end
                end

                # Timing info
                div style: "text-align: right; min-width: 150px;" do
                  div style: "font-size: 0.85rem; color: #666;" do
                    text "Loaded #{Admin.format_duration(app[:age_seconds])}"
                  end
                  div style: "font-size: 0.85rem; color: #888;" do
                    text "Idle #{Admin.format_duration(app[:idle_seconds])}"
                  end
                end

                # Actions
                div style: "display: flex; gap: 0.5rem;" do
                  # Open button - link to app
                  external_link_button "Open", url: "/apps/#{app[:id]}"

                  # Remove button
                  button "Remove", style: :secondary do |s|
                    Service.remove_app(app[:id])
                    s[:_refresh] = Time.now.to_i
                  end
                end
              end
            end
          end
        end

        # Footer with help
        div style: "margin-top: 2rem; padding-top: 1rem; border-top: 1px solid #e0e0e0;" do
          div style: "font-size: 0.85rem; color: #666;" do
            text "💡 Tip: Use streamweaver list to see apps from the command line"
          end
        end
      end
    end

    private

    def self.format_duration(seconds)
      return "just now" if seconds < 5

      if seconds < 60
        "#{seconds}s ago"
      elsif seconds < 3600
        "#{seconds / 60}m ago"
      elsif seconds < 86400
        "#{seconds / 3600}h ago"
      else
        "#{seconds / 86400}d ago"
      end
    end
  end
end
