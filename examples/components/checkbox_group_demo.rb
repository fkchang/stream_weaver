#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Sample email data
EMAILS = [
  { id: "email_1", from: "newsletter@techcrunch.com", subject: "Your Daily Tech Digest - AI News", date: "Jan 25, 10:32am" },
  { id: "email_2", from: "deals@retailer.com", subject: "Flash Sale: 50% Off Everything!", date: "Jan 25, 9:15am" },
  { id: "email_3", from: "no-reply@service.com", subject: "Your monthly statement is ready", date: "Jan 25, 8:45am" },
  { id: "email_4", from: "updates@social.com", subject: "You have 5 new notifications", date: "Jan 24, 4:30pm" },
  { id: "email_5", from: "support@vendor.com", subject: "Your ticket has been resolved", date: "Jan 24, 2:15pm" }
]

App = app "Spam Triage" do
  header "Spam Triage - #{EMAILS.length} emails to review"

  checkbox_group :selected_emails, select_all: "Select All", select_none: "Clear Selection" do
    EMAILS.each do |email|
      item email[:id] do
        div class: "email-row" do
          text "#{email[:from]}  #{email[:date]}"
          text email[:subject]
        end
      end
    end
  end

  # Show selected count
  selected = state[:selected_emails] || []
  if selected.any?
    text "#{selected.length} email(s) selected"

    button "Delete Selected", style: :secondary do |s|
      # In a real app, you'd delete the emails here
      s[:deleted] = s[:selected_emails].dup
      s[:selected_emails] = []
    end
  end

  if state[:deleted]&.any?
    text "Deleted #{state[:deleted].length} email(s): #{state[:deleted].join(', ')}"
  end
end

App.run! if __FILE__ == $0
