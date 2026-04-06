# frozen_string_literal: true

# URL Routing Demo
# Shows deep-linking, bookmarkable URLs, and browser back/forward
#
# Run with: ruby -r ./lib/stream_weaver examples/layout/routing_demo.rb
#
# Try:
#   - Click nav items and watch the URL bar update
#   - Visit /dashboard or /settings directly
#   - Press back/forward in the browser

require_relative '../../lib/stream_weaver'

app "URL Routing Demo" do
  route_by :page, home: "/", dashboard: "/dashboard", settings: "/settings"

  state[:page] ||= :home

  navbar do
    nav_item "Home",      href: "/",          active: state[:page] == :home
    nav_item "Dashboard", href: "/dashboard",  active: state[:page] == :dashboard
    nav_item "Settings",  href: "/settings",   active: state[:page] == :settings
  end

  case state[:page]
  when :home
    header "Home"
    text "Welcome! Click the nav links above — the URL bar updates and each page is bookmarkable."
    text "Try visiting /dashboard or /settings directly."
    button "Go to Dashboard" do |s|
      s[:page] = :dashboard
    end

  when :dashboard
    header "Dashboard"
    text "You navigated to /dashboard. Bookmark this URL and come back — it'll load right here."
    text_field :dashboard_note, label: "Notes", placeholder: "Type something..."
    button "Go to Settings" do |s|
      s[:page] = :settings
    end

  when :settings
    header "Settings"
    text "You're at /settings. Press the browser Back button to go back."
    checkbox :notifications, "Enable notifications"
    checkbox :dark_mode, "Dark mode"
    button "Back to Home" do |s|
      s[:page] = :home
    end
  end
end.run!
