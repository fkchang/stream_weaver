# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Pass theme as command line argument: ruby theme_demo.rb dashboard
THEME = (ARGV[0] || 'default').to_sym

# Sample data ------------------------------------------------------------

RECENT_ORDERS = [
  { order: "#10482", customer: "Alice Johnson", total: 128.50, status: "Shipped" },
  { order: "#10483", customer: "Bob Smith",     total: 64.00,  status: "Processing" },
  { order: "#10484", customer: "Carol Davis",   total: 342.10, status: "Delivered" },
  { order: "#10485", customer: "Dan Wilson",    total: 19.99,  status: "Cancelled" },
  { order: "#10486", customer: "Eve Turner",    total: 88.25,  status: "Shipped" }
].freeze

app = StreamWeaver::App.new("Theme Demo", theme: THEME, layout: :fluid) do
  # NOTE: section switching uses route_by + nav_item (plain <a href> links + GET routing)
  # rather than button-with-block, because StreamWeaver's button-action dispatcher
  # (find_button_recursive in server.rb) only walks component.children -- it does not
  # know about AppShell#main_children / #sidebar_children, so any `button ... do |s| end`
  # placed inside an app_shell's main/sidebar blocks is currently unreachable. Routing
  # (GET requests) goes through a separate code path and is unaffected.
  route_by :section, dashboard: "/", planning: "/planning", docs: "/docs", settings: "/settings"
  state[:section] ||= :dashboard

  app_shell sidebar_width: "220px", sidebar_position: :left do
    sidebar header: "Theme Demo" do
      vstack spacing: :xs do
        nav_item "Dashboard", href: "/",          active: state[:section] == :dashboard
        nav_item "Planning",  href: "/planning",  active: state[:section] == :planning
        nav_item "Docs",      href: "/docs",      active: state[:section] == :docs
        nav_item "Settings",  href: "/settings",  active: state[:section] == :settings
      end
    end

    main do
      navbar do
        hstack(justify: :between, align: :center) do
          header2 "StreamWeaver Themes"
          theme_switcher
        end
      end

      text "Use the theme switcher above to change themes in real-time!"
      text "Or run with: ruby theme_demo.rb [default|dashboard|document|doc]"

      breadcrumbs do
        crumb "Home", href: "/"
        crumb state[:section].to_s.capitalize
      end

      case state[:section]

      # =========================================================
      # SECTION 1: Dashboard
      # =========================================================
      when :dashboard
        header1 "Dashboard"

        pulse_indicator color: :green, label: "All Systems Operational"

        header2 "Key Metrics"
        kpi_dashboard metrics: [
          { value: "1,234",  label: "USERS",   color: :blue,   trend: :up },
          { value: "$45.6K", label: "REVENUE", color: :green,  trend: :up },
          { value: "+12.3%", label: "GROWTH",  color: :purple, trend: :up },
          { value: "3",      label: "ALERTS",  color: :red,    trend: :down }
        ]

        header2 "Trends"
        columns widths: ["1fr", "1fr"] do
          column do
            card do
              header3 "Revenue by Channel"
              bar_chart data: {
                "Web" => 4200, "Mobile" => 3100, "Partner" => 1800, "Retail" => 950
              }, colors: ["#4a90d9"], height: "220px"
            end
          end
          column do
            card do
              header3 "Weekly Active Users"
              line_chart data: [820, 932, 901, 934, 1290, 1330, 1420],
                         fill: true, colors: ["#10b981"], height: "220px"
            end
          end
        end

        header2 "Recent Orders"
        card do
          table RECENT_ORDERS do
            column :order
            column :customer
            column :total, format: :currency, align: :right
            column(:status) { |row| row[:status] }
          end
        end

        header2 "Status"
        hstack spacing: :lg, align: :center do
          vstack spacing: :xs, align: :center do
            status_dot status: :green, pulse: true
            text "API"
          end
          vstack spacing: :xs, align: :center do
            status_dot status: :green
            text "Database"
          end
          vstack spacing: :xs, align: :center do
            status_dot status: :yellow
            text "Queue"
          end
          vstack spacing: :xs, align: :center do
            status_dot status: :red
            text "CDN"
          end
        end

        hstack spacing: :md do
          badge "5", variant: :default
          badge "3", variant: :danger
          badge "12", variant: :warning
          badge "OK", variant: :success
        end

        status_badge :strong, "All core services healthy"

        header2 "Rollout Progress"
        progress_bar value: 72, show_label: true

        header2 "Activity Feed"
        vstack spacing: :none do
          activity_item time: "15:00", title: "Deployment completed",
                        summary: "v2.4.1 shipped to production, zero downtime",
                        type: :task
          activity_item time: "14:30", title: "Anomaly detected",
                        summary: "CDN latency spike in EU region, investigating",
                        type: :escalation
          activity_item time: "14:00", title: "Sprint planning notes shared",
                        summary: "Team aligned on Q3 priorities",
                        type: :communication
        end

      # =========================================================
      # SECTION 2: Planning
      # =========================================================
      when :planning
        header1 "Planning"
        text "A live look at the visual-plan skill: what's changing, open decisions, and mockups."

        header2 "Implementation Map"
        implementation_map(files: [
          { path: "lib/stream_weaver/theme/auto_mode.rb", note: "Fix contrast bug in default theme's muted text" },
          { path: "lib/stream_weaver/adapter/alpinejs.rb", note: "Add CSS variable fallback for table headers" },
          { path: "spec/theme_enhanced_spec.rb", note: "Cover new theme-switch edge cases" }
        ])

        header2 "Open Decision"
        decision(question: "Which theme should ship as the new default?") do
          option(id: :dashboard, label: "Dashboard (dark)",
                 detail: "High contrast, data-dense — best for ops/monitoring use cases.",
                 recommended: true)
          option(id: :default, label: "Default (light)",
                 detail: "Currently the least polished per design review — needs more work.")
          option(id: :document, label: "Document",
                 detail: "Best for long-form/reading contexts, not general app chrome.")
        end

        header2 "Code Change"
        diff(language: "ruby") do
          before do
            <<~RUBY
              def muted_text_color
                "#9ca3af"
              end
            RUBY
          end
          after do
            <<~RUBY
              def muted_text_color
                "var(--sw-text-muted, #9ca3af)"
              end
            RUBY
          end
        end

        header2 "Annotated Code"
        annotated_code(language: "ruby", annotations: [
          { line: 1, note: "Reads the CSS custom property set by the active theme" },
          { line: 2, note: "Falls back to a fixed hex value if the var is undefined" }
        ]) do
          <<~RUBY
            def muted_text_color
              "var(--sw-text-muted, #9ca3af)"
            end
          RUBY
        end

        header2 "Wireframe: Theme Switcher Placement"
        wireframe(surface: :browser) do
          <<~HTML
            <div class="wf-card">
              <h2>Navbar</h2>
              <p class="wf-muted">Theme switcher pinned top-right, always visible</p>
              <button class="primary">Theme: Dashboard ▾</button>
            </div>
          HTML
        end

        header2 "API Reference"
        api_endpoint method: "GET", path: "/api/themes",
                     description: "List available themes",
                     params: [
                       { name: "include_custom", type: "boolean", required: false }
                     ],
                     response: { themes: "array", default: "string" }

        header2 "Design Deck: Theme Token Strategy"
        design_deck "Theme Token Strategy" do
          slide "tokens", "CSS Variable Approach",
                context: "How should theme values propagate to components?" do
            option "CSS Custom Properties", aside: "Live-swappable at runtime, no rebuild needed.",
                   recommended: true do
              code_block <<~CSS, lang: "css"
                :root.sw-theme-dashboard {
                  --sw-bg: #0f172a;
                  --sw-text: #e2e8f0;
                }
              CSS
            end
            option "Sass Variables", aside: "Compile-time only — requires a rebuild per theme switch." do
              code_block <<~SCSS, lang: "scss"
                $sw-bg: #0f172a;
                $sw-text: #e2e8f0;
              SCSS
            end
          end

          slide "rollout", "Rollout Plan",
                context: "How do we ship the fixes without breaking existing embeds?" do
            option "Ship behind a flag", aside: "Safer, slower.", recommended: true do
              mermaid <<~MERMAID, compact: true
                graph LR
                  A[Fix CSS] --> B[Flag: theme_v2]
                  B --> C[Dogfood]
                  C --> D[Full rollout]
              MERMAID
            end
            option "Ship directly to all themes", aside: "Faster, riskier for existing embeds." do
              mermaid <<~MERMAID, compact: true
                graph LR
                  A[Fix CSS] --> B[Ship to all themes]
              MERMAID
            end
          end
        end

      # =========================================================
      # SECTION 3: Docs
      # =========================================================
      when :docs
        header1 "Docs"

        columns widths: ["260px", "1fr"] do
          column do
            sidebar_toc sections: [
              { id: "overview",   label: "Overview" },
              { id: "callouts",   label: "Callouts" },
              { id: "comparison", label: "Before / After" },
              { id: "diagram",    label: "Diagram" },
              { id: "files",      label: "File Layout" }
            ]
          end

          column do
            doc_header(
              eyebrow: "StreamWeaver · Theming",
              title: "Theme System Overview",
              pills: [
                { text: "Stable" },
                "Updated July 2026",
                "Owner: core team"
              ]
            )

            doc_section_header "01", "Overview", id: "overview"
            md <<~MD
              StreamWeaver ships four built-in themes: **default**, **dashboard**, **document**,
              and **doc**. Each theme is a set of CSS custom properties applied at the `body` level.
            MD

            prose do
              text "Themes are swappable live via the theme_switcher component, with no page reload required."
            end

            pullquote "Design for the brain you have, not the brain you wish you had.",
                      attribution: "Gloria Foloran"

            doc_section_header "02", "Callouts", id: "callouts"
            callout(variant: :info, title: "Tip:") do
              text "Use the theme_switcher component to preview all themes without restarting the server."
            end
            callout(variant: :warning, title: "Heads up:") do
              text "Custom CSS overrides may not survive a theme switch unless scoped to a theme class."
            end
            callout(variant: :success, title: "Verified:") do
              text "All four built-in themes now pass the contrast-ratio audit."
            end

            doc_section_header "03", "Before / After", id: "comparison"
            comparison(before_label: "Before", after_label: "After") do
              before do
                md "- Flat, single-page demo\n- ~15 components shown\n- Hard to judge real-app fit"
              end
              after do
                md "- Sidebar-navigable admin app\n- 40+ components shown\n- Realistic layout per section"
              end
            end

            doc_section_header "04", "Diagram", id: "diagram"
            mermaid <<~MERMAID
              graph LR
                A[Theme Switcher] --> B[body.sw-theme-*]
                B --> C[CSS Custom Properties]
                C --> D[Component Styles]
            MERMAID

            doc_section_header "05", "File Layout", id: "files"
            dir_tree <<~TREE
              examples/styling/
                theme_demo.rb [modified]
                style_showcase.rb
                feedback_demo.rb
            TREE

            code_editor :sample_snippet, language: :ruby, readonly: true, height: "160px",
                        default: <<~RUBY
                          app_shell do
                            sidebar { text "Nav" }
                            main { text "Content" }
                          end
                        RUBY
          end
        end

      # =========================================================
      # SECTION 4: Settings
      # =========================================================
      when :settings
        header1 "Settings"

        header2 "Typography"
        header3 "Headings"
        text "This is a paragraph demonstrating body text. The quick brown fox jumps over the lazy dog."

        header3 "Lists and Content"
        text "Content flows naturally with appropriate spacing and line height for readability."

        header2 "Cards"
        card do
          card_header "Card Title"
          card_body do
            text "Card content with some description text. Notice how the card styling changes between themes."
          end
        end

        header2 "Buttons"
        hstack(spacing: :sm) do
          button "Primary Button"
          button "Secondary", style: :secondary
        end

        header2 "Form Inputs"
        columns widths: ["1fr", "1fr"] do
          column do
            text_field :name, placeholder: "Enter your name"
          end
          column do
            select :color, ["Red", "Green", "Blue"]
          end
        end
        checkbox :agree, "I agree to the terms"

        header2 "Checkbox Group"
        checkbox_group :permissions, select_all: "Select All", select_none: "Clear" do
          item "read" do
            text "Read - View content"
          end
          item "write" do
            text "Write - Create and edit content"
          end
          item "admin" do
            text "Admin - Full access"
          end
        end

        header2 "Radio Group"
        radio_group :plan, ["Free", "Pro", "Enterprise"]

        header2 "Dropdown"
        select :theme_pref, ["Light", "Dark", "System"], default: "System"
        dropdown do
          trigger do
            button "Actions", style: :primary
          end
          menu do
            menu_item "Edit" do |s|
              s[:last_action] = "Edit clicked"
            end
            menu_item "Duplicate" do |s|
              s[:last_action] = "Duplicate clicked"
            end
            menu_divider
            menu_item "Delete", style: :destructive do |s|
              s[:last_action] = "Delete clicked"
            end
          end
        end
        text -> (s) { s[:last_action] ? "Last action: #{s[:last_action]}" : "Click a menu item..." }

        header2 "Tags"
        tag_buttons :category, ["Fiction", "Non-fiction", "Mystery", "Sci-Fi"]

        header2 "Tabs"
        tabs :settings_tabs, variant: :line do
          tab "General" do
            text "General settings content."
          end
          tab "Notifications" do
            checkbox :email_notifs, "Email notifications"
            checkbox :sms_notifs, "SMS notifications"
          end
          tab "Advanced" do
            spinner size: :md, label: "Loading advanced settings..."
          end
        end

        header2 "Collapsible"
        collapsible "Advanced Options", expanded: false do
          text "Hidden content revealed when expanded."
          checkbox :debug_mode, "Enable debug mode"
        end

        header2 "Expandable Card"
        expandable_card key: :settings_expanded, title: "Account", subtitle: "Profile & billing",
                        badge_text: "2 items", status: :green do
          text "Expandable card content — click the header to collapse."
        end

        header2 "Alerts"
        alert(variant: :info) { text "This is an info alert" }
        alert(variant: :success) { text "Success message" }

        header2 "Progress & Spinners"
        progress_bar value: 65, show_label: true
        spinner size: :md, label: "Loading..."

        header2 "Modal"
        button "Open Settings Modal" do |s|
          s[:settings_modal_open] = true
        end
        modal :settings_modal, title: "Settings", size: :md do
          text "Adjust your preferences here."
          checkbox :dark_mode, "Enable dark mode"
          modal_footer do
            button "Cancel", style: :secondary do |s|
              s[:settings_modal_open] = false
            end
            button "Save", style: :primary do |s|
              s[:settings_modal_open] = false
            end
          end
        end

        header2 "Toasts"
        toast_container position: :top_right, duration: 4000
        button "Show Toast" do |s|
          show_toast("Settings saved successfully!", variant: :success)
        end

        header2 "Data Display"
        text "Themes affect data density and scannability."
        card do
          card_body do
            grid cols: 3 do
              vstack do
                text "Users"
                header3 "1,234"
              end
              vstack do
                text "Revenue"
                header3 "$45.6K"
              end
              vstack do
                text "Growth"
                header3 "+12.3%"
              end
            end
          end
        end
      end
    end
  end
end

app.generate.run!
