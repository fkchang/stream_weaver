# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

app = StreamWeaver::App.new("Feedback Components Demo") do
  header1 "Feedback Components"
  text "Demonstrating alerts, toasts, progress bars, and spinners."

  # =========================================
  # Alerts Section
  # =========================================
  header2 "Alerts"
  text "Static feedback messages with different variants."

  alert(variant: :info) do
    text "This is an informational alert. Use it for general messages."
  end

  alert(variant: :success, title: "Success!") do
    text "Your changes have been saved successfully."
  end

  alert(variant: :warning, title: "Warning") do
    text "Your session will expire in 5 minutes."
  end

  alert(variant: :error, title: "Error") do
    text "Unable to connect to the server. Please try again."
  end

  header3 "Dismissible Alerts"

  alert(variant: :info, title: "Tip", dismissible: true) do
    text "Click the X to dismiss this alert. It's only removed client-side."
  end

  alert(variant: :success, dismissible: true) do
    text "You can dismiss me too!"
  end

  # =========================================
  # Toast Notifications Section
  # =========================================
  header2 "Toast Notifications"
  text "Temporary notifications that stack and auto-dismiss. Click buttons to add multiple toasts!"

  # Add a toast container - this is where toasts will appear
  toast_container position: :top_right, duration: 4000

  state[:toast_count] ||= 0

  hstack(spacing: :sm) do
    button "Info Toast" do |s|
      s[:toast_count] += 1
      show_toast("Info message ##{s[:toast_count]}", variant: :info)
    end

    button "Success Toast" do |s|
      s[:toast_count] += 1
      show_toast("Success! Operation ##{s[:toast_count]} completed.", variant: :success)
    end

    button "Warning Toast" do |s|
      s[:toast_count] += 1
      show_toast("Warning: Check item ##{s[:toast_count]}", variant: :warning)
    end

    button "Error Toast" do |s|
      s[:toast_count] += 1
      show_toast("Error ##{s[:toast_count]}: Something went wrong!", variant: :error)
    end
  end

  hstack(spacing: :sm) do
    button "Add 3 Toasts", style: :secondary do |s|
      show_toast("First notification", variant: :info)
      show_toast("Second notification", variant: :success)
      show_toast("Third notification", variant: :warning)
    end

    button "Clear All", style: :secondary do |s|
      clear_toasts
      s[:toast_count] = 0
    end
  end

  text -> (s) { "Total toasts shown: #{s[:toast_count]}" }

  # =========================================
  # Progress Bars Section
  # =========================================
  header2 "Progress Bars"
  text "Visual indicators for progress and completion."

  header3 "Static Progress"

  text "Default (25%):"
  progress_bar value: 25

  text "Success variant (50%):"
  progress_bar value: 50, variant: :success

  text "Warning variant (75%):"
  progress_bar value: 75, variant: :warning

  text "Error variant (90%):"
  progress_bar value: 90, variant: :error

  header3 "With Labels"

  text "Progress with label:"
  progress_bar value: 65, show_label: true

  header3 "Animated"

  text "Animated striped progress:"
  progress_bar value: 80, animated: true, variant: :success

  header3 "Dynamic Progress"
  text "Click buttons to change progress:"

  # Initialize progress state
  state[:progress] ||= 30

  progress_bar value: :progress, show_label: true, variant: :success

  hstack(spacing: :sm) do
    button "- 10", style: :secondary do |s|
      s[:progress] = [0, s[:progress] - 10].max
    end

    button "+ 10" do |s|
      s[:progress] = [100, s[:progress] + 10].min
    end

    button "Reset", style: :secondary do |s|
      s[:progress] = 0
    end

    button "Complete" do |s|
      s[:progress] = 100
    end
  end

  # =========================================
  # Spinners Section
  # =========================================
  header2 "Spinners"
  text "Loading indicators for async operations."

  header3 "Sizes"

  hstack(spacing: :lg, align: :center) do
    vstack(align: :center) do
      spinner size: :sm
      text "Small"
    end

    vstack(align: :center) do
      spinner size: :md
      text "Medium"
    end

    vstack(align: :center) do
      spinner size: :lg
      text "Large"
    end
  end

  header3 "With Labels"

  spinner size: :md, label: "Loading data..."
  spinner size: :sm, label: "Processing..."

  # =========================================
  # Combined Example
  # =========================================
  header2 "Combined Example: File Upload Simulation"

  state[:upload_status] ||= :idle
  state[:upload_progress] ||= 0

  card do
    card_header "Upload Status"
    card_body do
      case state[:upload_status]
      when :idle
        text "Select a file to upload."
        button "Start Upload" do |s|
          s[:upload_status] = :uploading
          s[:upload_progress] = 0
        end

      when :uploading
        hstack(align: :center, spacing: :sm) do
          spinner size: :sm, label: "Uploading..."
        end
        progress_bar value: :upload_progress, show_label: true, animated: true

        hstack(spacing: :sm) do
          button "+ Progress" do |s|
            s[:upload_progress] += 20
            if s[:upload_progress] >= 100
              s[:upload_status] = :complete
              s[:upload_progress] = 100
            end
          end

          button "Cancel", style: :secondary do |s|
            s[:upload_status] = :idle
            s[:upload_progress] = 0
          end
        end

      when :complete
        alert(variant: :success, title: "Upload Complete!") do
          text "Your file has been uploaded successfully."
        end

        button "Upload Another", style: :secondary do |s|
          s[:upload_status] = :idle
          s[:upload_progress] = 0
        end
      end
    end
  end
end

app.generate.run!
