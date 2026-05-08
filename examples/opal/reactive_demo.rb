# frozen_string_literal: true
# Demo: ReactiveState — watch, on_start, and computed/derived state
# Build: bundle exec streamweaver opal-build examples/opal/reactive_demo.rb --output dist/reactive_demo
# Open: open dist/reactive_demo/index.html

app "Reactive Demo" do
  # ── S8: Loan Calculator (derived state, no useMemo needed) ──────────
  card do
    header2 "Loan Calculator"
    text_field :principal, label: "Loan Amount ($)", type: :number
    text_field :rate,      label: "Annual Rate (%)", type: :number
    text_field :term,      label: "Term (months)",   type: :number

    p       = state[:principal].to_f
    r       = state[:rate].to_f / 100.0 / 12.0
    n       = state[:term].to_f
    payment = (r > 0 && n > 0) ? (p * r * (1 + r)**n) / ((1 + r)**n - 1) : 0.0

    card do
      header3 "Monthly Payment"
      text "$#{"%.2f" % payment}"
    end
  end

  div(style: "height: 32px")

  # ── S5: Watch — filter list reacts to search ──────────────────────
  card do
    header2 "Search Filter (watch)"
    watch(:search_query) do |query|
      all = %w[Apple Banana Blueberry Cherry Cranberry Date Elderberry Fig Grape]
      state[:filtered] = query.to_s.empty? ? all : all.select { |f| f.downcase.include?(query.downcase) }
    end

    text_field :search_query, placeholder: "Type to filter fruit..."

    div do
      (state[:filtered] || %w[Apple Banana Blueberry Cherry Cranberry Date Elderberry Fig Grape]).each do |fruit|
        text fruit
      end
    end
  end

  div(style: "height: 32px")

  # ── S6: on_start — runs once after first render ───────────────────
  card do
    header2 "on_start Demo"
    state[:items] = state[:items] || []
    on_start do
      state[:items] = ["Loaded Item A", "Loaded Item B", "Loaded Item C"]
    end

    if state[:items].empty?
      text "Loading..."
    else
      state[:items].each { |item| text item }
    end
  end
end
