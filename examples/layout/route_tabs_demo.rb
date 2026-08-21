# frozen_string_literal: true

# Route tabs demo: two url: true tab groups (bookmarkable, back/forward-aware)
# plus a deferred form to exercise the morph-does-not-revert-the-tab behavior.
#
#   PORT=4573 ruby examples/layout/route_tabs_demo.rb
#   open http://127.0.0.1:4573/?view=2&panel=1
require_relative "../../lib/stream_weaver"

app = StreamWeaver.app "Route Tabs Demo" do
  header1 "Route Tabs Demo"

  tabs :view, url: true do
    tab "Overview" do
      header3 "Overview"
      text "The overview panel. Bookmark me with ?view=0."
    end
    tab "Findings" do
      header3 "Findings"
      text "The findings panel. Bookmark me with ?view=1."
    end
    tab "Details" do
      header3 "Details"
      text "The details panel. Bookmark me with ?view=2."
      form :notes_form do
        text_field :note, placeholder: "Add a note"
        submit "Save note" do |values|
          state[:last_note] = values[:note]
        end
      end
      md "Last saved note: **#{state[:last_note] || '(none)'}**"
    end
  end

  # Read BELOW the tabs declaration: above it, state[:view] still holds the raw
  # pre-authority param (or stale session value) -- the resolved integer only
  # exists once the group has applied URL authority.
  md "Active view index (server-resolved): **#{state[:view].inspect}**"

  md "---"

  tabs :panel, url: true, variant: :enclosed do
    tab "Alpha" do
      text "Second group, panel Alpha (?panel=0)."
    end
    tab "Beta" do
      text "Second group, panel Beta (?panel=1)."
    end
  end
end

app.run!(open_browser: false) if __FILE__ == $PROGRAM_NAME
