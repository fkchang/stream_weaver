# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# FAC-P2.1 dream-DSL cases from gsd/analysis/decisions/table-cells.md section 8:
# rivet's dedup_review fake card+hstack table, and finance_dashboard's raw
# <span style="color:..."> negative-balance hack -- both become real `table`
# usage once cells accept components.
RSpec.describe "StreamWeaver table cell composition end-to-end (FAC-P2.1)" do
  include Rack::Test::Methods

  let(:app) { described_app.generate }

  def button_ids(html)
    html.scan(%r{hx-post="/action/([a-z0-9_]+(?:-dup-\d+)?)"}).flatten
  end

  describe "rivet dedup_review-style action-button table" do
    let(:described_app) do
      StreamWeaver::App.new("Dedup Review") do
        candidate_pairs = [
          { id: 1, name: "Alice", email: "alice@example.com", score: 0.9 },
          { id: 2, name: "Bob", email: "bob@example.com", score: 0.7 }
        ]

        table candidate_pairs, row_key: ->(pair) { pair[:id] } do
          column :name
          column :email
          column :score, format: :percent, align: :right
          column :actions do |pair|
            hstack do
              button("Merge", style: :primary) { |state| (state[:merged] ||= []) << pair[:id] }
              button("Dismiss", style: :secondary) { |state| (state[:dismissed] ||= []) << pair[:id] }
            end
          end
        end
      end
    end

    it "renders per-row Merge/Dismiss buttons with distinct ids" do
      get '/'
      ids = button_ids(last_response.body)
      merge_ids = ids.select { |id| id.start_with?("btn_merge_") }
      dismiss_ids = ids.select { |id| id.start_with?("btn_dismiss_") }
      expect(merge_ids.uniq.length).to eq(2)
      expect(dismiss_ids.uniq.length).to eq(2)
    end

    it "dispatches row 2's Merge button to row 2's callback, not row 1's" do
      get '/'
      ids = button_ids(last_response.body)
      merge_ids = ids.select { |id| id.start_with?("btn_merge_") }

      post "/action/#{merge_ids[1]}", {}
      expect(last_request.session[:streamlit_state][:merged]).to eq([2])

      post "/action/#{merge_ids[0]}", {}
      expect(last_request.session[:streamlit_state][:merged]).to eq([2, 1])
    end

    it "dispatches row 1's Dismiss button independently of row 1's Merge button" do
      get '/'
      ids = button_ids(last_response.body)
      dismiss_ids = ids.select { |id| id.start_with?("btn_dismiss_") }

      post "/action/#{dismiss_ids[0]}", {}
      expect(last_request.session[:streamlit_state][:dismissed]).to eq([1])
      expect(last_request.session[:streamlit_state][:merged]).to be_nil
    end
  end

  describe "finance_dashboard-style negative-balance badge cell" do
    let(:described_app) do
      StreamWeaver::App.new("Finance") do
        accounts = [
          { id: 1, name: "Checking", balance: -42.50 },
          { id: 2, name: "Savings", balance: 1200.00 }
        ]

        table accounts do
          column :name
          column :balance, format: :currency do |account|
            account[:balance].negative? ? badge(format("$%.2f", account[:balance]), variant: :danger) : account[:balance]
          end
        end
      end
    end

    it "renders a real badge component for the negative balance, no raw HTML" do
      get '/'
      expect(last_response.body).not_to include("<span style=")
      expect(last_response.body).to include("$-42.50")
    end

    it "renders the positive balance as a plain formatted scalar" do
      get '/'
      expect(last_response.body).to include("$1,200")
    end
  end
end
