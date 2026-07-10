# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe "Automatic loading indicators (FAC-P1.5)" do
  include Rack::Test::Methods

  describe "buttons" do
    let(:app) do
      StreamWeaver::App.new("Loading Indicators App") do
        button("Default") { |s| s[:clicked] = true }
        button("Opted Out", loading: false) { |s| s[:clicked] = true }
      end.generate
    end

    it "emits an id and an hx-indicator attribute pointing at itself and #app-container by default" do
      get '/'
      button_html = last_response.body[/<button[^>]*>Default<\/button>/]
      id = button_html[/id="([^"]+)"/, 1]

      expect(id).not_to be_nil
      expect(button_html).to include(%(hx-indicator="##{id}, #app-container"))
    end

    it "does not add the sw-no-loading-indicator class by default" do
      get '/'
      button_html = last_response.body[/<button[^>]*>Default<\/button>/]
      expect(button_html).not_to include("sw-no-loading-indicator")
    end

    it "loading: false omits hx-indicator and adds the suppression class" do
      get '/'
      button_html = last_response.body[/<button[^>]*>Opted Out<\/button>/]

      expect(button_html).not_to include("hx-indicator")
      expect(button_html).to include("sw-no-loading-indicator")
    end
  end

  describe "app-level loading_indicators: false" do
    let(:app) do
      StreamWeaver::App.new("No Indicators App", loading_indicators: false) do
        button("Click Me") { |s| s[:clicked] = true }
        text_field :name
        select :color, ["Red", "Green"]
        checkbox :agree, "Agree"
      end.generate
    end

    it "omits hx-indicator on buttons and adds the suppression class" do
      get '/'
      button_html = last_response.body[/<button[^>]*>Click Me<\/button>/]
      expect(button_html).not_to include("hx-indicator")
      expect(button_html).to include("sw-no-loading-indicator")
    end

    it "omits hx-indicator on text fields" do
      get '/'
      input_html = last_response.body[/<input[^>]*id="input-name"[^>]*>/]
      expect(input_html).not_to include("hx-indicator")
    end

    it "omits hx-indicator on selects" do
      get '/'
      select_html = last_response.body[/<select[^>]*name="color"[^>]*>/]
      expect(select_html).not_to include("hx-indicator")
    end

    it "omits hx-indicator on checkboxes" do
      get '/'
      checkbox_html = last_response.body[/<input[^>]*id="checkbox_agree"[^>]*>/]
      expect(checkbox_html).not_to include("hx-indicator")
    end
  end

  describe "text fields, selects, and checkboxes" do
    let(:app) do
      StreamWeaver::App.new("Field Indicators App") do
        text_field :name
        select :color, ["Red", "Green"]
        checkbox :agree, "Agree"
      end.generate
    end

    it "text field points hx-indicator at #app-container by default" do
      get '/'
      input_html = last_response.body[/<input[^>]*id="input-name"[^>]*>/]
      expect(input_html).to include(%(hx-indicator="#app-container"))
    end

    it "select points hx-indicator at #app-container by default" do
      get '/'
      select_html = last_response.body[/<select[^>]*name="color"[^>]*>/]
      expect(select_html).to include(%(hx-indicator="#app-container"))
    end

    it "checkbox points hx-indicator at #app-container by default" do
      get '/'
      checkbox_html = last_response.body[/<input[^>]*id="checkbox_agree"[^>]*>/]
      expect(checkbox_html).to include(%(hx-indicator="#app-container"))
    end
  end

  describe "form submit button" do
    let(:app) do
      StreamWeaver::App.new("Form Indicators App") do
        form :contact do
          text_field :email
          submit("Send") { |s, v| }
        end
      end.generate
    end

    it "emits a stable id and hx-indicator pointing at itself and #app-container" do
      get '/'
      button_html = last_response.body[/<button[^>]*>Send<\/button>/]
      expect(button_html).to include(%(id="form-contact-submit"))
      expect(button_html).to include(%(hx-indicator="#form-contact-submit, #app-container"))
    end
  end

  describe "CSS" do
    # NOTE: StreamWeaver::CSS.full_stylesheet regex-extracts a `raw(safe(<<~CSS))`
    # pattern that no longer exists in views.rb (the stylesheet now lives in the
    # `master_theme_css` class method) -- a pre-existing bug independent of this
    # feature, so these assertions target the actual live source directly.
    it "views.rb's stylesheet includes .htmx-request rules for the swap target" do
      css = StreamWeaver::Views::AppView.master_theme_css
      expect(css).to include("#app-container.htmx-request")
      expect(css).to include("transition-delay: 150ms")
    end

    it "the button spinner rule respects the sw-no-loading-indicator opt-out class" do
      css = StreamWeaver::Views::AppView.master_theme_css
      expect(css).to include("button.htmx-request:not(.sw-no-loading-indicator)::after")
    end

    it "css.rb's animation_css also includes the swap-target busy rules (live/Opal parity)" do
      css = StreamWeaver::CSS.animation_css
      expect(css).to include("#app-container.htmx-request")
    end

    it "uses theme tokens rather than hardcoded colors for the new rules" do
      css = StreamWeaver::CSS.animation_css
      indicator_block = css[/#app-container \{.*?\}\s*#app-container\.htmx-request \{.*?\}/m]
      expect(indicator_block).to include("var(--sw-transition-fast")
    end
  end
end
