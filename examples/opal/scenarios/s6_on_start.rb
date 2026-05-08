# frozen_string_literal: true
# S6: on_start — Async Fetch on Mount
# React equivalent: useEffect(() => { fetch('/api/items').then(...) }, [])
# StreamWeaver: on_start { } — fires exactly once after first render

app "S6 — on_start: Async Fetch on Mount" do
  on_start do
    after(0.8) do
      state[:items] = ["Dashboard Report", "Weekly Summary", "Q2 Forecast", "Team Updates", "Release Notes"]
    end
  end

  if state[:items]
    badge "Loaded via on_start", color: :green
    div(style: "height:8px")
    state[:items].each { |item| text "• #{item}" }
  else
    text "Loading..."
  end
end
