# frozen_string_literal: true
# S7: Multi-Step Wizard / State Machine
# React equivalent: useReducer — dispatch events to a pure transition function
# StreamWeaver: case/when is the reducer — Ruby already has this

app "S7 — Multi-Step Wizard" do
  case (state[:step] || :info)
  when :info
    header3 "Step 1 of 3 — Your Info"
    text_field :name,  label: "Full Name"
    text_field :email, label: "Email"
    button("Next →") { state[:step] = :payment }

  when :payment
    header3 "Step 2 of 3 — Payment"
    text_field :card, label: "Card Number"
    button("← Back") { state[:step] = :info    }
    button("Next →") { state[:step] = :confirm }

  when :confirm
    header3 "Step 3 of 3 — Review"
    text "Name: #{state[:name]}"
    text "Email: #{state[:email]}"
    text "Card: #{state[:card]}"
    button("← Back")   { state[:step] = :payment }
    button("Submit ✓") { state[:step] = :done    }

  when :done
    badge "Submitted!", color: :green
    text "Welcome, #{state[:name]}."
    button("Start over") { state[:step] = :info }
  end
end
