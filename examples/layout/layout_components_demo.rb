#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstrates the new layout components and custom component mechanism:
# - Custom component modules (components: option)
# - Card sub-components (card_header, card_body, card_footer)
# - VStack and HStack for stacking layouts
# - Grid for responsive grid layouts

require_relative '../../lib/stream_weaver'

# Custom component module - defines reusable components
module UserComponents
  def user_card(user)
    card do
      card_header do
        header4 user[:name]
        status_badge user[:status], user[:role]
      end
      card_body do
        text user[:bio]
        text "Email: #{user[:email]}"
      end
      card_footer do
        button "View Profile", style: :secondary
        button "Message"
      end
    end
  end

  def stat_card(label, value, trend: nil)
    card do
      card_header label
      card_body do
        header2 value
        if trend
          text trend
        end
      end
    end
  end
end

# Example data
USERS = [
  { name: "Alice Chen", email: "alice@example.com", bio: "Full-stack developer", status: :strong, role: "Engineering" },
  { name: "Bob Smith", email: "bob@example.com", bio: "Product designer", status: :maybe, role: "Design" },
  { name: "Carol Davis", email: "carol@example.com", bio: "Data scientist", status: :strong, role: "Analytics" },
  { name: "Dan Wilson", email: "dan@example.com", bio: "DevOps engineer", status: :skip, role: "Infrastructure" },
  { name: "Eve Johnson", email: "eve@example.com", bio: "Frontend specialist", status: :strong, role: "Engineering" },
  { name: "Frank Brown", email: "frank@example.com", bio: "Backend architect", status: :maybe, role: "Engineering" }
].freeze

App = app "Layout Components Demo", layout: :wide, components: [UserComponents] do
  header1 "StreamWeaver Layout Components"

  md "This demo showcases the new layout components: **vstack**, **hstack**, **grid**, and **card sub-components**."

  # Section 1: Card Sub-Components
  header2 "Card Sub-Components"

  card do
    card_header "Structured Card"
    card_body do
      text "Cards can now have distinct header, body, and footer sections."
      text "Headers get a bottom border, footers get a top border and right-aligned content."
    end
    card_footer do
      button "Cancel", style: :secondary
      button "Save Changes"
    end
  end

  # Section 2: VStack - Vertical Stacking
  header2 "VStack - Vertical Stacking"

  vstack spacing: :lg do
    text "Items stacked vertically with large spacing"
    text "Second item"
    text "Third item"
  end

  header3 "VStack with Dividers"

  vstack spacing: :md, divider: true do
    text "Item with divider below"
    text "Another item with divider"
    text "Last item (no divider)"
  end

  # Section 3: HStack - Horizontal Stacking
  header2 "HStack - Horizontal Stacking"

  hstack spacing: :md, align: :center do
    button "Action 1"
    button "Action 2", style: :secondary
    button "Action 3", style: :secondary
  end

  header3 "HStack with Justify"

  hstack spacing: :sm, justify: :between do
    text "Left content"
    text "Right content"
  end

  # Section 4: Grid - Responsive Layouts
  header2 "Grid - Responsive Layouts"

  header3 "Fixed 3-Column Grid"

  grid columns: 3, gap: :md do
    stat_card("Total Users", "1,234", trend: "+12% this month")
    stat_card("Active Sessions", "567", trend: "+8% today")
    stat_card("Revenue", "$45.2K", trend: "+23% YoY")
  end

  header3 "Responsive Grid (resize browser to see)"
  text "1 column on mobile, 2 on tablet, 3 on desktop"

  grid columns: [1, 2, 3], gap: :lg do
    USERS.each do |user|
      user_card(user)
    end
  end

  # Section 5: Custom Components
  header2 "Custom Components via Modules"

  md <<~MD
    The `user_card` and `stat_card` used above are defined in a `UserComponents` module
    and included via the `components:` option:

    ```ruby
    module UserComponents
      def user_card(user)
        card do
          card_header { header4 user[:name] }
          card_body { text user[:bio] }
          card_footer { button "View" }
        end
      end
    end

    app "My App", components: [UserComponents] do
      user_card(current_user)
    end
    ```
  MD

  # Section 6: Nested Layouts
  header2 "Nested Layouts"

  columns widths: ['30%', '70%'] do
    column do
      vstack spacing: :sm do
        header3 "Sidebar"
        text "VStack inside a Column"
        text "Another stacked item"
      end
    end

    column do
      grid columns: 2, gap: :sm do
        card { text "Grid item 1" }
        card { text "Grid item 2" }
        card { text "Grid item 3" }
        card { text "Grid item 4" }
      end
    end
  end
end

App.run! if __FILE__ == $0
