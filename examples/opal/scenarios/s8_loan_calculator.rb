# frozen_string_literal: true
# S8: Loan Calculator — Interdependent Derived Fields
# React equivalent: useMemo with [principal, rate, term] dependency array
# StreamWeaver: inline computation — no memoization annotation needed

app "S8 — Loan Calculator" do
  text_field :principal, label: "Loan Amount ($)",  type: :number
  text_field :rate,      label: "Annual Rate (%)",  type: :number
  text_field :term,      label: "Term (months)",    type: :number

  p       = state[:principal].to_f
  r       = state[:rate].to_f / 100.0 / 12.0
  n       = state[:term].to_f
  payment = (r > 0 && n > 0) ? (p * r * (1 + r)**n) / ((1 + r)**n - 1) : 0.0

  div(style: "height:16px")
  card do
    header3 "Monthly Payment"
    text "$#{"%.2f" % payment}"
  end
end
