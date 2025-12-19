# frozen_string_literal: true

# Form Block Demo - demonstrates deferred submission forms
#
# Run with: ruby examples/form_demo.rb

require_relative '../lib/stream_weaver'

app = StreamWeaver.app "Form Block Demo" do
  header1 "Form Blocks Demo"

  md "This example demonstrates **deferred submission forms**. Form fields don't sync with the server until you click Submit."

  # Pre-populate form state (simulating loading from database)
  state[:edit_profile] ||= {
    name: "Alice",
    status: "active",
    notes: "Initial notes..."
  }

  header2 "Edit Profile"

  form :edit_profile do
    text_field :name, placeholder: 'Your name'
    select :status, %w[active paused archived]
    text_area :notes, placeholder: 'Notes about this person...', rows: 4

    submit 'Save Changes' do |form_values|
      # This runs AFTER state[:edit_profile] is updated
      puts "Form submitted with: #{form_values.inspect}"
    end

    cancel 'Reset'
  end

  # Show current state (updates after form submit)
  header2 "Current State"
  card do
    text "Name: #{state.dig(:edit_profile, :name)}"
    text "Status: #{state.dig(:edit_profile, :status)}"
    text "Notes: #{state.dig(:edit_profile, :notes)}"
  end

  md "---"
  md "**How it works:**"
  md "- Type in the fields - nothing syncs to server yet"
  md "- Click **Save Changes** - all values sent in one request"
  md "- Click **Reset** - fields revert to original values (client-side only)"

  md "---"
  md "**Note:** State persists in browser cookies across server restarts. Click below to start fresh:"
  button "Reset Demo", style: :secondary do |s|
    s.clear
  end

  header2 "Standalone Field (for comparison)"
  md "This field syncs immediately on change:"
  text_field :standalone_field, placeholder: "Type here - syncs immediately"
  text "Standalone value: #{state[:standalone_field]}"
end

app.run!
