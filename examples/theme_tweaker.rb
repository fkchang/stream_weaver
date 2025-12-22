# frozen_string_literal: true

require_relative "../lib/stream_weaver"

# StreamWeaver Theme Tweaker
# A visual editor for creating and customizing themes

app = StreamWeaver::App.new("StreamWeaver Theme Tweaker", layout: :wide) do
  # Initialize state
  state[:theme_name] ||= "my_custom_theme"
  state[:base_theme] ||= "default"
  state[:export_format] ||= "ruby"
  state[:show_export] ||= false

  # Initialize editable variables with defaults
  state[:font_family] ||= "'Source Sans 3', system-ui, sans-serif"
  state[:font_size_base] ||= "17px"
  state[:line_height] ||= "1.7"
  state[:color_primary] ||= "#c2410c"
  state[:color_primary_hover] ||= "#9a3412"
  state[:color_text] ||= "#111111"
  state[:color_text_muted] ||= "#444444"
  state[:color_bg] ||= "#f8f8f8"
  state[:color_bg_card] ||= "#ffffff"
  state[:color_border] ||= "#e0e0e0"
  state[:spacing_md] ||= "1.25rem"
  state[:radius_md] ||= "6px"
  state[:card_border_left] ||= "3px solid var(--sw-color-primary)"

  hstack(justify: :between, align: :center) do
    header1 "Theme Tweaker"
    theme_switcher
  end

  text "Create custom themes by adjusting CSS variables. Preview changes live, then export as Ruby or JSON."

  columns widths: ["320px", "1fr"] do
    # Left column: Controls
    column do
      card do
        card_header "Theme Settings"
        card_body do
          text "Theme Name"
          text_field :theme_name, placeholder: "my_custom_theme"

          text "Base Theme"
          select :base_theme, %w[default dashboard document]

          button "Apply Base Theme", style: :secondary do |s|
            # Reset to base theme defaults
            case s[:base_theme]
            when "default"
              s[:font_family] = "'Source Sans 3', system-ui, sans-serif"
              s[:font_size_base] = "17px"
              s[:line_height] = "1.7"
              s[:color_primary] = "#c2410c"
              s[:color_primary_hover] = "#9a3412"
              s[:color_text] = "#111111"
              s[:color_text_muted] = "#444444"
              s[:color_bg] = "#f8f8f8"
              s[:color_bg_card] = "#ffffff"
              s[:color_border] = "#e0e0e0"
              s[:spacing_md] = "1.25rem"
              s[:radius_md] = "6px"
              s[:card_border_left] = "3px solid var(--sw-color-primary)"
            when "dashboard"
              s[:font_family] = "'Source Sans 3', system-ui, sans-serif"
              s[:font_size_base] = "15px"
              s[:line_height] = "1.5"
              s[:color_primary] = "#c2410c"
              s[:color_primary_hover] = "#9a3412"
              s[:color_text] = "#111111"
              s[:color_text_muted] = "#555555"
              s[:color_bg] = "#fafafa"
              s[:color_bg_card] = "#ffffff"
              s[:color_border] = "#e5e5e5"
              s[:spacing_md] = "0.875rem"
              s[:radius_md] = "4px"
              s[:card_border_left] = "1px solid var(--sw-color-border)"
            when "document"
              s[:font_family] = "'Crimson Pro', Georgia, serif"
              s[:font_size_base] = "19px"
              s[:line_height] = "1.85"
              s[:color_primary] = "#6b7280"
              s[:color_primary_hover] = "#4b5563"
              s[:color_text] = "#1a1a1a"
              s[:color_text_muted] = "#4a4a4a"
              s[:color_bg] = "#faf8f5"
              s[:color_bg_card] = "#ffffff"
              s[:color_border] = "#e8e4df"
              s[:spacing_md] = "1.5rem"
              s[:radius_md] = "8px"
              s[:card_border_left] = "none"
            end
          end
        end
      end

      collapsible "Typography", expanded: true do
        text "Font Family"
        text_field :font_family, placeholder: "'Source Sans 3', system-ui, sans-serif"

        text "Base Font Size"
        text_field :font_size_base, placeholder: "17px"

        text "Line Height"
        text_field :line_height, placeholder: "1.7"
      end

      collapsible "Colors", expanded: true do
        text "Primary Color"
        text_field :color_primary, placeholder: "#c2410c"

        text "Primary Hover"
        text_field :color_primary_hover, placeholder: "#9a3412"

        text "Text Color"
        text_field :color_text, placeholder: "#111111"

        text "Muted Text"
        text_field :color_text_muted, placeholder: "#444444"

        text "Background"
        text_field :color_bg, placeholder: "#f8f8f8"

        text "Card Background"
        text_field :color_bg_card, placeholder: "#ffffff"

        text "Border Color"
        text_field :color_border, placeholder: "#e0e0e0"
      end

      collapsible "Spacing & Borders" do
        text "Spacing (md)"
        text_field :spacing_md, placeholder: "1.25rem"

        text "Border Radius (md)"
        text_field :radius_md, placeholder: "6px"

        text "Card Left Border"
        text_field :card_border_left, placeholder: "3px solid var(--sw-color-primary)"
      end

      card do
        card_header "Export"
        card_body do
          select :export_format, %w[ruby json]

          hstack do
            button "Generate Export" do |s|
              s[:show_export] = true
            end

            button "Copy to Clipboard", style: :secondary do |s|
              # Note: actual clipboard copy requires JS, this just shows the code
              s[:show_export] = true
            end
          end
        end
      end
    end

    # Right column: Preview
    column do
      # Preview container with inline style overrides
      div(
        class: "theme-preview-container",
        style: <<~CSS.gsub("\n", " ")
          --sw-font-family: #{state[:font_family]};
          --sw-font-size-base: #{state[:font_size_base]};
          --sw-line-height: #{state[:line_height]};
          --sw-color-primary: #{state[:color_primary]};
          --sw-color-primary-hover: #{state[:color_primary_hover]};
          --sw-color-text: #{state[:color_text]};
          --sw-color-text-muted: #{state[:color_text_muted]};
          --sw-color-bg: #{state[:color_bg]};
          --sw-color-bg-card: #{state[:color_bg_card]};
          --sw-color-border: #{state[:color_border]};
          --sw-spacing-md: #{state[:spacing_md]};
          --sw-radius-md: #{state[:radius_md]};
          --sw-card-border-left: #{state[:card_border_left]};
          padding: var(--sw-spacing-md);
          background: var(--sw-color-bg);
          border-radius: 8px;
          font-family: var(--sw-font-family);
          font-size: var(--sw-font-size-base);
          line-height: var(--sw-line-height);
          color: var(--sw-color-text);
        CSS
      ) do
        header2 "Live Preview"

        text "This preview shows how your theme looks. Adjust the controls on the left to see changes."

        header3 "Typography"
        text "Regular paragraph text demonstrating the body font styling. The quick brown fox jumps over the lazy dog."

        header3 "Components"

        card do
          card_header "Sample Card"
          card_body do
            text "Card content demonstrating spacing and border styling."

            hstack do
              button "Primary Button"
              button "Secondary", style: :secondary
            end
          end
        end

        header3 "Form Elements"
        text_field :preview_input, placeholder: "Sample text input"
        checkbox :preview_checkbox, "Sample checkbox option"

        header3 "Alerts"
        alert(variant: :info) { text "This is an info alert message." }
        alert(variant: :success) { text "Success! Operation completed." }

        header3 "Progress"
        progress_bar value: 65, show_label: true
      end

      # Export code display
      if state[:show_export]
        header3 "Export Code"

        variables = {
          font_family: state[:font_family],
          font_size_base: state[:font_size_base],
          line_height: state[:line_height],
          color_primary: state[:color_primary],
          color_primary_hover: state[:color_primary_hover],
          color_text: state[:color_text],
          color_text_muted: state[:color_text_muted],
          color_bg: state[:color_bg],
          color_bg_card: state[:color_bg_card],
          color_border: state[:color_border],
          spacing_md: state[:spacing_md],
          radius_md: state[:radius_md],
          card_border_left: state[:card_border_left]
        }

        export_code = if state[:export_format] == "ruby"
          vars = variables.map { |k, v| "  #{k}: #{v.inspect}" }.join(",\n")
          <<~RUBY
            # Add this to your app file before creating the app
            StreamWeaver.register_theme :#{state[:theme_name]}, {
            #{vars}
            }, base: :#{state[:base_theme]}, label: "#{state[:theme_name].split('_').map(&:capitalize).join(' ')}", description: "Custom theme"

            # Then use it in your app:
            app "My App", theme: :#{state[:theme_name]} do
              # ...
            end
          RUBY
        else
          JSON.pretty_generate({
            name: state[:theme_name],
            label: state[:theme_name].split('_').map(&:capitalize).join(' '),
            description: "Custom theme",
            base_theme: state[:base_theme],
            variables: variables
          })
        end

        text_area :export_output, rows: 15, default: export_code
      end
    end
  end
end

app.generate.run!
