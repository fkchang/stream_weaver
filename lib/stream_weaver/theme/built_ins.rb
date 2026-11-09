# frozen_string_literal: true

# The framework's own themes: the one list of built-in names. Each registers
# its label, description and the fonts its page head loads; its CSS is
# hand-tuned and stays in Views::AppView.master_theme_css
# (body.sw-theme-<name>), so no variables are registered here.
module StreamWeaver
  register_built_in_theme :default,   label: "Default",   description: "Warm Industrial"
  register_built_in_theme :dashboard, label: "Dashboard", description: "Data Dense"
  register_built_in_theme :document,  label: "Document",  description: "Reading Mode"
  register_built_in_theme :dark,      label: "Dark",      description: "Cabinet Control"
  register_built_in_theme :doc,       label: "Doc",       description: "Compact Editorial"
  register_built_in_theme :ide,       label: "IDE",       description: "Editor Workspace",
                                      fonts: ["JetBrains+Mono:wght@400;500;600;700"],
                                      stylesheets: ["https://cdn.jsdelivr.net/npm/@fontsource-variable/geist@5.2.8/index.css"]
end
