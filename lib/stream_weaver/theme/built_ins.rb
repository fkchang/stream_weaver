# frozen_string_literal: true

# The framework's own themes: the one list of built-in names. Each registers
# its label, description and the fonts its page head loads; its CSS is
# hand-tuned and stays in Views::AppView.master_theme_css
# (body.sw-theme-<name>), so no variables are registered here.
module StreamWeaver
  register_theme :default,   label: "Default",   description: "Warm Industrial",   built_in: true
  register_theme :dashboard, label: "Dashboard", description: "Data Dense",        built_in: true
  register_theme :document,  label: "Document",  description: "Reading Mode",      built_in: true
  register_theme :dark,      label: "Dark",      description: "Cabinet Control",   built_in: true
  register_theme :doc,       label: "Doc",       description: "Compact Editorial", built_in: true
  register_theme :ide,       label: "IDE",       description: "Editor Workspace",  built_in: true,
                             fonts: ["JetBrains+Mono:wght@400;500;600;700"],
                             stylesheets: ["https://cdn.jsdelivr.net/npm/@fontsource-variable/geist@5.2.8/index.css"]
end
