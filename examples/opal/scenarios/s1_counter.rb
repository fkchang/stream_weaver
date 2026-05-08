# frozen_string_literal: true
# S1: Counter with Derived Display
# React equivalent: useState + useMemo
# StreamWeaver: inline computation, zero annotation

app "S1 — Counter with Derived Display" do
  button("Increment") { state[:count] = state[:count].to_i + 1 }
  button("Reset") { state[:count] = 0 }

  card do
    text "Count: #{state[:count].to_i}"
    text "Is even: #{state[:count].to_i.even?}"
    text "Double: #{state[:count].to_i * 2}"
  end
end
