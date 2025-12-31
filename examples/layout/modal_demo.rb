# frozen_string_literal: true

# Modal Demo - demonstrates modal dialogs
#
# Run with: ruby examples/modal_demo.rb

require_relative '../../lib/stream_weaver'

app = StreamWeaver.app "Modal Demo" do
  header1 "Modal Dialogs Demo"

  md "This example demonstrates **modal dialogs** with different sizes and use cases."

  # Initialize state
  state[:items] ||= ["Item 1", "Item 2", "Item 3"]
  state[:item_to_delete] ||= nil
  state[:form_submitted] ||= false

  # =========================================
  # Basic Modal
  # =========================================
  header2 "Basic Modal"

  button "Open Basic Modal" do |s|
    s[:basic_modal_open] = true
  end

  modal :basic_modal, title: "Welcome!" do
    text "This is a basic modal dialog."
    md "Modals are great for:"
    md "- Confirmations\n- Forms\n- Detailed information\n- Alerts"

    modal_footer do
      button "Got it!", style: :primary do |s|
        s[:basic_modal_open] = false
      end
    end
  end

  # =========================================
  # Confirmation Modal
  # =========================================
  header2 "Confirmation Modal"
  md "Click an item to delete it (with confirmation):"

  card do
    state[:items].each_with_index do |item, idx|
      hstack justify: :between, align: :center do
        text item
        button "Delete", style: :secondary do |s|
          s[:item_to_delete] = idx
          s[:confirm_delete_open] = true
        end
      end
    end

    if state[:items].empty?
      text "No items. Add some below!"
    end
  end

  button "Add Item" do |s|
    s[:items] << "Item #{s[:items].length + 1}"
  end

  modal :confirm_delete, title: "Confirm Delete", size: :sm do
    text "Are you sure you want to delete this item?"
    text "This action cannot be undone."

    modal_footer do
      button "Cancel", style: :secondary do |s|
        s[:confirm_delete_open] = false
        s[:item_to_delete] = nil
      end
      button "Delete" do |s|
        if s[:item_to_delete]
          s[:items].delete_at(s[:item_to_delete])
        end
        s[:confirm_delete_open] = false
        s[:item_to_delete] = nil
      end
    end
  end

  # =========================================
  # Form Modal
  # =========================================
  header2 "Form in Modal"

  button "Open Form Modal" do |s|
    s[:form_modal_open] = true
    s[:form_submitted] = false
  end

  if state[:form_submitted]
    card do
      text "Form submitted!"
      text "Name: #{state[:modal_name]}"
      text "Email: #{state[:modal_email]}"
    end
  end

  modal :form_modal, title: "Contact Form", size: :md do
    text "Fill out the form below:"

    text_field :modal_name, placeholder: "Your name"
    text_field :modal_email, placeholder: "your@email.com"
    text_area :modal_message, placeholder: "Your message...", rows: 3

    modal_footer do
      button "Cancel", style: :secondary do |s|
        s[:form_modal_open] = false
      end
      button "Submit" do |s|
        s[:form_submitted] = true
        s[:form_modal_open] = false
      end
    end
  end

  # =========================================
  # Size Variations
  # =========================================
  header2 "Modal Sizes"
  md "Modals come in four sizes: `:sm`, `:md` (default), `:lg`, and `:xl`"

  hstack spacing: :md do
    button "Small (sm)" do |s|
      s[:size_sm_open] = true
    end
    button "Medium (md)" do |s|
      s[:size_md_open] = true
    end
    button "Large (lg)" do |s|
      s[:size_lg_open] = true
    end
    button "XL" do |s|
      s[:size_xl_open] = true
    end
  end

  modal :size_sm, title: "Small Modal", size: :sm do
    text "This is a small modal (400px max width)."
    text "Good for simple confirmations."
    modal_footer do
      button "Close" do |s|
        s[:size_sm_open] = false
      end
    end
  end

  modal :size_md, title: "Medium Modal", size: :md do
    text "This is a medium modal (560px max width)."
    text "The default size, good for most use cases."
    modal_footer do
      button "Close" do |s|
        s[:size_md_open] = false
      end
    end
  end

  modal :size_lg, title: "Large Modal", size: :lg do
    text "This is a large modal (800px max width)."
    text "Good for forms with more fields or detailed content."
    md "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
    modal_footer do
      button "Close" do |s|
        s[:size_lg_open] = false
      end
    end
  end

  modal :size_xl, title: "Extra Large Modal", size: :xl do
    text "This is an extra large modal (1140px max width)."
    text "Good for complex content like data tables or multi-column layouts."

    columns widths: ['50%', '50%'] do
      column do
        header4 "Left Column"
        text "Some content on the left side."
        text_field :xl_field_1, placeholder: "Field 1"
      end
      column do
        header4 "Right Column"
        text "Some content on the right side."
        text_field :xl_field_2, placeholder: "Field 2"
      end
    end

    modal_footer do
      button "Close" do |s|
        s[:size_xl_open] = false
      end
    end
  end

  # =========================================
  # Usage notes
  # =========================================
  md """
---
**How it works:**
- Modals use state key `:{modal_key}_open` to control visibility
- Set to `true` to open, `false` to close
- Close by: clicking backdrop, pressing Escape, or button action
- Sizes: `:sm` (400px), `:md` (560px), `:lg` (800px), `:xl` (1140px)
"""

  md "---"
  button "Reset Demo", style: :secondary do |s|
    s.clear
  end
end

app.run!
