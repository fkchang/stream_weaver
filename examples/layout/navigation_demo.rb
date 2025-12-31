# frozen_string_literal: true

# Navigation Components Demo
# Demonstrates Tabs, Breadcrumbs, and Dropdown/Menu components
#
# Run with: ruby -r ./lib/stream_weaver examples/navigation_demo.rb

require_relative '../../lib/stream_weaver'

app "Navigation Components", layout: :wide do
  header "Navigation Components Demo"
  text "This demo showcases the Phase 2 navigation components: Tabs, Breadcrumbs, and Dropdown menus."

  # =========================================
  # Breadcrumbs
  # =========================================
  header2 "Breadcrumbs"
  text "Navigate hierarchical content with breadcrumb trails."

  breadcrumbs do
    crumb "Home", href: "/"
    crumb "Products", href: "/products"
    crumb "Electronics", href: "/products/electronics"
    crumb "Laptops"  # Current page - no href
  end

  text "Custom separator:"
  breadcrumbs separator: ">" do
    crumb "Dashboard", href: "/dashboard"
    crumb "Settings", href: "/settings"
    crumb "Profile"
  end

  # =========================================
  # Tabs - Line Variant (default)
  # =========================================
  header2 "Tabs - Line Variant"
  text "Classic underline tabs - clean and minimal."

  tabs :demo_tabs, variant: :line do
    tab "Overview" do
      card do
        card_header "Overview Tab"
        card_body do
          text "This is the overview content. Tabs maintain state on the server, so switching tabs persists across page refreshes."
          text_field :overview_input, placeholder: "Type something here..."
        end
      end
    end

    tab "Details" do
      card do
        card_header "Details Tab"
        card_body do
          text "Here are the details. Each tab can contain any StreamWeaver components."
          vstack spacing: :sm do
            checkbox :detail_option1, "Enable feature A"
            checkbox :detail_option2, "Enable feature B"
          end
        end
      end
    end

    tab "Settings" do
      card do
        card_header "Settings Tab"
        card_body do
          text "Configure your preferences here."
          select :theme, ["Light", "Dark", "System"], default: "System"
        end
      end
    end
  end

  # =========================================
  # Tabs - Enclosed Variant
  # =========================================
  header2 "Tabs - Enclosed Variant"
  text "Traditional boxed tabs with borders."

  tabs :enclosed_tabs, variant: :enclosed do
    tab "First" do
      text "Content for the first enclosed tab."
    end
    tab "Second" do
      text "Content for the second enclosed tab."
    end
    tab "Third" do
      text "Content for the third enclosed tab."
    end
  end

  # =========================================
  # Tabs - Soft Rounded Variant
  # =========================================
  header2 "Tabs - Soft Rounded Variant"
  text "Modern pill-style tabs with rounded backgrounds."

  tabs :rounded_tabs, variant: :"soft-rounded" do
    tab "All" do
      text "Showing all items."
    end
    tab "Active" do
      text "Showing only active items."
    end
    tab "Archived" do
      text "Showing archived items."
    end
  end

  # =========================================
  # Dropdown Menu
  # =========================================
  header2 "Dropdown Menu"
  text "Click the button to reveal a dropdown menu with actions."

  hstack spacing: :md, align: :center do
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
        menu_item "Archive" do |s|
          s[:last_action] = "Archive clicked"
        end
        menu_item "Delete", style: :destructive do |s|
          s[:last_action] = "Delete clicked"
        end
      end
    end

    dropdown do
      trigger do
        button "More Options", style: :secondary
      end

      menu do
        menu_item "View Profile" do |s|
          s[:last_action] = "View Profile clicked"
        end
        menu_item "Account Settings" do |s|
          s[:last_action] = "Account Settings clicked"
        end
        menu_divider
        menu_item "Sign Out", style: :destructive do |s|
          s[:last_action] = "Sign Out clicked"
        end
      end
    end

    text -> (s) { s[:last_action] ? "Last action: #{s[:last_action]}" : "Click a menu item..." }
  end

  # =========================================
  # Combined Example
  # =========================================
  header2 "Combined Example"
  text "Navigation components work together seamlessly."

  breadcrumbs do
    crumb "App", href: "/"
    crumb "Users", href: "/users"
    crumb "John Doe"
  end

  hstack spacing: :md, justify: :between, align: :center do
    header3 "User Profile"

    dropdown do
      trigger do
        button "User Actions", style: :secondary
      end

      menu do
        menu_item "Edit Profile" do |s|
          s[:profile_action] = "editing"
        end
        menu_item "Change Password" do |s|
          s[:profile_action] = "password"
        end
        menu_divider
        menu_item "Deactivate Account", style: :destructive do |s|
          s[:profile_action] = "deactivate"
        end
      end
    end
  end

  tabs :user_tabs do
    tab "Info" do
      vstack spacing: :sm do
        text "Name: John Doe"
        text "Email: john@example.com"
        text "Role: Administrator"
      end
    end

    tab "Activity" do
      text "Recent activity will be shown here."
    end

    tab "Permissions" do
      checkbox_group :permissions, select_all: "Select All", select_none: "Clear" do
        item "read" do
          text "Read - View content"
        end
        item "write" do
          text "Write - Create and edit content"
        end
        item "delete" do
          text "Delete - Remove content"
        end
        item "admin" do
          text "Admin - Full access"
        end
      end
    end
  end
end.run!
