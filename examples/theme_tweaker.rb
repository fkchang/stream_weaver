# frozen_string_literal: true

require_relative "../lib/stream_weaver"

# StreamWeaver Theme Tweaker
# A visual editor for creating and customizing themes
#
# Note: Edit values in the controls, then click "Update Preview" to see changes.
# This avoids flashing from constant re-renders on every keystroke.

app = StreamWeaver::App.new("StreamWeaver Theme Tweaker", layout: :fluid) do
  # Initialize state
  state[:theme_name] ||= "my_custom_theme"
  state[:base_theme] ||= "default"
  state[:export_format] ||= "ruby"
  state[:show_export] ||= false

  # Preview values (what's currently shown in preview)
  # These only update when "Update Preview" is clicked
  state[:preview] ||= {
    font_family: "'Source Sans 3', system-ui, sans-serif",
    font_size_base: "17px",
    line_height: "1.7",
    color_primary: "#c2410c",
    color_primary_hover: "#9a3412",
    color_text: "#111111",
    color_text_muted: "#444444",
    color_bg: "#f8f8f8",
    color_bg_card: "#ffffff",
    color_border: "#e0e0e0",
    spacing_md: "1.25rem",
    radius_md: "6px",
    card_border_left: "3px solid #c2410c"
  }

  # Form values (what's being edited)
  state[:font_family] ||= state[:preview][:font_family]
  state[:font_size_base] ||= state[:preview][:font_size_base]
  state[:line_height] ||= state[:preview][:line_height]
  state[:color_primary] ||= state[:preview][:color_primary]
  state[:color_primary_hover] ||= state[:preview][:color_primary_hover]
  state[:color_text] ||= state[:preview][:color_text]
  state[:color_text_muted] ||= state[:preview][:color_text_muted]
  state[:color_bg] ||= state[:preview][:color_bg]
  state[:color_bg_card] ||= state[:preview][:color_bg_card]
  state[:color_border] ||= state[:preview][:color_border]
  state[:spacing_md] ||= state[:preview][:spacing_md]
  state[:radius_md] ||= state[:preview][:radius_md]
  state[:card_border_left] ||= state[:preview][:card_border_left]

  hstack(justify: :between, align: :center) do
    header1 "Theme Tweaker"
    hstack do
      button "Update Preview" do |s|
        # Copy form values to preview
        s[:preview] = {
          font_family: s[:font_family],
          font_size_base: s[:font_size_base],
          line_height: s[:line_height],
          color_primary: s[:color_primary],
          color_primary_hover: s[:color_primary_hover],
          color_text: s[:color_text],
          color_text_muted: s[:color_text_muted],
          color_bg: s[:color_bg],
          color_bg_card: s[:color_bg_card],
          color_border: s[:color_border],
          spacing_md: s[:spacing_md],
          radius_md: s[:radius_md],
          card_border_left: s[:card_border_left]
        }
      end
      theme_switcher
    end
  end

  text "Edit theme values below, then click 'Update Preview' to see changes. Export when ready."

  columns widths: ["340px", "1fr"] do
    # Left column: Controls
    column do
      card do
        card_header "Theme Settings"
        card_body do
          text "Theme Name"
          text_field :theme_name, placeholder: "my_custom_theme"

          text "Base Theme"
          select :base_theme, %w[default dashboard document]

          button "Load Base Theme", style: :secondary do |s|
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
              s[:card_border_left] = "3px solid #c2410c"
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
              s[:card_border_left] = "1px solid #e5e5e5"
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
            # Also update preview immediately
            s[:preview] = {
              font_family: s[:font_family],
              font_size_base: s[:font_size_base],
              line_height: s[:line_height],
              color_primary: s[:color_primary],
              color_primary_hover: s[:color_primary_hover],
              color_text: s[:color_text],
              color_text_muted: s[:color_text_muted],
              color_bg: s[:color_bg],
              color_bg_card: s[:color_bg_card],
              color_border: s[:color_border],
              spacing_md: s[:spacing_md],
              radius_md: s[:radius_md],
              card_border_left: s[:card_border_left]
            }
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
        text_field :card_border_left, placeholder: "3px solid #c2410c"
      end

      card do
        card_header "Export"
        card_body do
          select :export_format, %w[ruby json]

          button "Generate Export" do |s|
            s[:show_export] = true
          end
        end
      end
    end

    # Right column: Preview
    column do
      # Get preview values
      pv = state[:preview]

      # Build inline style string with CSS variable overrides
      preview_style = [
        "--sw-font-family: #{pv[:font_family]}",
        "--sw-font-body: #{pv[:font_family]}",
        "--sw-font-size-base: #{pv[:font_size_base]}",
        "--sw-line-height: #{pv[:line_height]}",
        "--sw-color-primary: #{pv[:color_primary]}",
        "--sw-color-primary-hover: #{pv[:color_primary_hover]}",
        "--sw-color-text: #{pv[:color_text]}",
        "--sw-color-text-muted: #{pv[:color_text_muted]}",
        "--sw-color-bg: #{pv[:color_bg]}",
        "--sw-color-bg-card: #{pv[:color_bg_card]}",
        "--sw-color-border: #{pv[:color_border]}",
        "--sw-spacing-md: #{pv[:spacing_md]}",
        "--sw-radius-md: #{pv[:radius_md]}",
        "--sw-card-border-left: #{pv[:card_border_left]}",
        "padding: 1.5rem",
        "background: #{pv[:color_bg]}",
        "border-radius: 8px",
        "border: 1px solid #{pv[:color_border]}"
      ].join("; ")

      # Preview container with CSS variable overrides
      div(style: preview_style) do
        header2 "Live Preview"

        text "This preview reflects your current theme settings. Click 'Update Preview' after making changes."

        header3 "Typography"
        text "Regular paragraph text demonstrating the body font styling. The quick brown fox jumps over the lazy dog. Notice the font family, size, and line height."

        header3 "Card Component"

        card do
          card_header "Sample Card Title"
          card_body do
            text "Card content demonstrating border, background, and spacing styles."

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

        text_area :export_output, rows: 18, default: export_code
      end
    end
  end
end

app.generate.run!
