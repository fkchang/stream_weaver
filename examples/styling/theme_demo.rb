# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Pass theme as command line argument: ruby theme_demo.rb dashboard
THEME = (ARGV[0] || 'default').to_sym

app = StreamWeaver::App.new("Theme Demo", theme: THEME) do
  # Theme switcher in top right
  hstack(justify: :between, align: :center) do
    header1 "StreamWeaver Themes"
    theme_switcher
  end

  text "Use the theme switcher above to change themes in real-time!"
  text "Or run with: ruby theme_demo.rb [default|dashboard|document]"

  # =========================================
  # Typography
  # =========================================
  header2 "Typography"

  header3 "Headings"
  text "This is a paragraph demonstrating body text. The quick brown fox jumps over the lazy dog. This sentence shows how regular content looks in this theme."

  header3 "Lists and Content"
  text "Content flows naturally with appropriate spacing and line height for readability."

  # =========================================
  # Components
  # =========================================
  header2 "Components"

  header3 "Cards"
  card do
    card_header "Card Title"
    card_body do
      text "Card content with some description text. Notice how the card styling changes between themes."
    end
  end

  header3 "Buttons"
  hstack(spacing: :sm) do
    button "Primary Button"
    button "Secondary", style: :secondary
  end

  header3 "Form Inputs"
  columns widths: ["1fr", "1fr"] do
    column do
      text_field :name, placeholder: "Enter your name"
    end
    column do
      select :color, ["Red", "Green", "Blue"]
    end
  end

  checkbox :agree, "I agree to the terms"

  header3 "Alerts"
  alert(variant: :info) { text "This is an info alert" }
  alert(variant: :success) { text "Success message" }

  header3 "Progress"
  progress_bar value: 65, show_label: true

  # =========================================
  # Data Display
  # =========================================
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

app.generate.run!
