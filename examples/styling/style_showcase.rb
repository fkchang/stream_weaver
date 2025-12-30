# frozen_string_literal: true

# Style Showcase - Comprehensive test of StreamWeaver styling
#
# Tests:
# - All header levels h1-h6
# - Typography (bold, italic, code, links)
# - Long content overflow handling
# - Form elements
# - Cards and layouts
# - Layout modes (default/wide/full)
#
# Usage: ruby examples/style_showcase.rb

require_relative '../lib/stream_weaver'

LAYOUT = (ARGV[0] || 'wide').to_sym  # Pass layout as argument: ruby style_showcase.rb fluid

StreamWeaver.app "Style Showcase", layout: LAYOUT do
  header1 "StreamWeaver Style Showcase"
  md "**Current layout: `#{LAYOUT}`**"
  md "Options: `default` (900px) | `wide` (1100px) | `full` (1400px) | `fluid` (100%)"
  md "Test: `ruby style_showcase.rb fluid`"

  # Typography Section
  header2 "Typography Hierarchy"

  card do
    header1 "Header 1 - Page Title (2.25rem)"
    header2 "Header 2 - Section (1.625rem)"
    header3 "Header 3 - Subsection (1.25rem)"
    header4 "Header 4 - Group (1.1rem)"
    header5 "Header 5 - Minor (1rem)"
    header6 "Header 6 - Label (0.9rem uppercase)"
  end

  header2 "Text Formatting"

  card do
    md "**Bold text** for emphasis."
    md "*Italic text* for subtle emphasis."
    md "`Inline code` for technical terms."
    md "[Links](https://example.com) for navigation."
    md "Regular paragraph text with good line height for readability. This should be easy to read even in longer blocks of content. The font is Source Sans 3 at 17px."
  end

  # Overflow Handling Section
  header2 "Overflow & Long Content"

  card do
    header3 "Long URL"
    text "https://example.com/this/is/a/very/long/url/path/that/should/wrap/properly/instead/of/breaking/the/layout/or/causing/horizontal/scroll"
  end

  card do
    header3 "Long Word"
    text "Supercalifragilisticexpialidocious and Pneumonoultramicroscopicsilicovolcanoconiosis should wrap properly."
  end

  card do
    header3 "Wide Content"
    text "Column 1 | Column 2 | Column 3 | Column 4 | Column 5 | Column 6 | Column 7 | Column 8"
    text "Data that might be wider than expected in some cases with lots of information packed in."
  end

  # Form Elements Section
  header2 "Form Elements"

  header3 "Text Inputs"
  text_field :name, placeholder: "Enter your name"
  text_area :bio, placeholder: "Enter a longer description..."

  header3 "Selection Controls"
  checkbox :enabled, "Enable feature"
  select :color, ["Red", "Green", "Blue"], default: "Green"

  header3 "Radio Group"
  radio_group :size, ["Small", "Medium", "Large"]

  header3 "Buttons"
  columns do
    column do
      button "Primary Action" do |s|
        s[:clicked] = "primary"
      end
    end
    column do
      button "Secondary Action", style: :secondary do |s|
        s[:clicked] = "secondary"
      end
    end
  end

  # Cards Section
  header2 "Cards"

  card do
    header3 "Simple Card"
    text "Cards provide visual grouping with a subtle terracotta accent bar."
  end

  card do
    header3 "Card with Form"
    form :card_form do
      text_field :card_input, placeholder: "Input inside a card"
      submit "Submit"
    end
  end

  # Columns Layout Section
  header2 "Column Layouts"

  header3 "Equal Width Columns"
  columns do
    column do
      card do
        header4 "Column 1"
        text "Equal width via flexbox."
      end
    end
    column do
      card do
        header4 "Column 2"
        text "Also equal width."
      end
    end
    column do
      card do
        header4 "Column 3"
        text "Three columns total."
      end
    end
  end

  header3 "Custom Width Columns"
  columns widths: ['30%', '70%'] do
    column do
      card do
        header4 "Sidebar (30%)"
        text "Narrower column for navigation or metadata."
      end
    end
    column do
      card do
        header4 "Main Content (70%)"
        text "Wider column for primary content. This layout is useful for detail pages with a sidebar."
      end
    end
  end

  # Collapsible Section
  header2 "Collapsible Sections"

  collapsible "Click to expand details" do
    text "This content is hidden by default and revealed on click."
    text "Useful for progressive disclosure of complex information."
  end

  collapsible "Already expanded section", expanded: true do
    text "This section starts open."
  end

  # Current State Display
  header2 "Current State"
  text "Name: #{state[:name]}"
  text "Bio: #{state[:bio]}"
  text "Enabled: #{state[:enabled]}"
  text "Color: #{state[:color]}"
  text "Size: #{state[:size]}"
  text "Last clicked: #{state[:clicked] || '(none)'}"
end.run!
