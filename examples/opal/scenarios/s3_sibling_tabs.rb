# frozen_string_literal: true
# S3: Sibling Coordination via Shared State
# React equivalent: lift state to parent, thread props down to both siblings
# StreamWeaver: state[:key] is already global — no lifting needed

app "S3 — Sibling Coordination" do
  tabs :active_tab do
    tab "Config" do
      text_field :theme_name, label: "Theme Name"
      text_field :app_name,   label: "App Name"
      button("Light theme") { state[:dark] = false }
      button("Dark theme")  { state[:dark] = true  }
    end

    tab "Preview" do
      bg = state[:dark] ? "#1a1a2e" : "#ffffff"
      fg = state[:dark] ? "#e0e0e0" : "#1a1a1a"
      div(style: "background:#{bg};color:#{fg};padding:24px;border-radius:8px") do
        header2 state[:app_name] || "My App"
        text "Theme: #{state[:theme_name] || "(none set)"}"
        text "Mode: #{state[:dark] ? "Dark" : "Light"}"
      end
    end
  end
end
