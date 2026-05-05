#!/usr/bin/env ruby
# frozen_string_literal: true
# Opal Phase 2b UAT — tabs + sortable table
# Build: streamweaver opal-build examples/basic/opal_tabs_table.rb
# Open:  open dist/index.html

require_relative '../../lib/stream_weaver'

App = app "Opal Phase 2b: Tabs + Table" do
  header1 "Opal Phase 2b UAT"

  tabs :section do
    tab "People" do
      header3 "Sortable Table — click column headers to sort"
      table :people,
        headers: ["Name", "Department", "Score"],
        rows: [
          ["Alice",   "Engineering", "92"],
          ["Bob",     "Design",      "78"],
          ["Carol",   "Engineering", "85"],
          ["Dave",    "Product",     "90"],
          ["Eve",     "Design",      "88"]
        ],
        sortable: true,
        striped: true
    end

    tab "Settings" do
      header3 "Settings Tab"
      text_field :query, placeholder: "Search..."
      text "You typed: #{state[:query]}" if state[:query] && !state[:query].empty?
    end

    tab "About" do
      header3 "About"
      md "**Opal Phase 2b** adds `render_tabs` and `render_table` to the Opal adapter using the `register_callbacks` protocol."
      md "- Tabs switch without a server round-trip"
      md "- Table sorts client-side (click a column header)"
      md "- All using the same DSL as server-side StreamWeaver"
    end
  end
end

App.run! if __FILE__ == $0
