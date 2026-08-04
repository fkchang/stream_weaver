# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# FAC-9u2 visual pass: text_field/text_area/select/date_field/chip_group all
# accepted a label: option, but only date_field actually rendered it --
# the rest silently dropped it, so modal/form inputs showed as bare boxes.
RSpec.describe "Input labels render visibly by default (FAC-9u2)" do
  include Rack::Test::Methods

  let(:app) { described_app.generate }

  describe "text_field" do
    let(:described_app) do
      StreamWeaver::App.new("Labels") do
        text_field :name, label: "Full name"
        text_field :nickname
      end
    end

    it "renders the label when given" do
      get '/'
      expect(last_response.body).to include(%(<label class="sw-field__label" for="input-name">Full name</label>))
    end

    it "renders no label when omitted" do
      get '/'
      nickname_input = last_response.body[/<input[^>]*id="input-nickname"[^>]*>/]
      expect(last_response.body.scan("<label").length).to eq(1)
      expect(nickname_input).not_to be_nil
    end
  end

  describe "text_area" do
    let(:described_app) do
      StreamWeaver::App.new("Labels") { text_area :bio, label: "Biography" }
    end

    it "renders the label when given" do
      get '/'
      expect(last_response.body).to include(%(<label class="sw-field__label" for="input-bio">Biography</label>))
    end
  end

  describe "select" do
    let(:described_app) do
      StreamWeaver::App.new("Labels") { select :color, ["Red", "Green"], label: "Favorite color" }
    end

    it "renders the label when given" do
      get '/'
      expect(last_response.body).to include(">Favorite color</label>")
      expect(last_response.body).to match(/<label[^>]*for="select-color"[^>]*>Favorite color<\/label>/)
    end
  end

  describe "date_field (already worked -- regression guard)" do
    let(:described_app) do
      StreamWeaver::App.new("Labels") { date_field :dob, label: "Date of birth" }
    end

    it "still renders the label" do
      get '/'
      # date_field now shares the sw-field/sw-field__label wrapper with every
      # other input (previously bespoke .sw-date-field__label).
      expect(last_response.body).to include(%(<label class="sw-field__label" for="input-dob">Date of birth</label>))
    end
  end

  describe "chip_group" do
    let(:described_app) do
      StreamWeaver::App.new("Labels") { chip_group :tags, %w[Family Friend], label: "Tags" }
    end

    it "renders a group-level label when given" do
      get '/'
      expect(last_response.body).to match(/<label[^>]*>Tags<\/label>/)
    end
  end
end
