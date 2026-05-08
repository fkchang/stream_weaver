# frozen_string_literal: true
# backtick_javascript: true
# S6: on_start — Async Fetch on Mount
# React equivalent: useEffect(() => { fetch('/api/items').then(...) }, [])
# StreamWeaver: on_start { } — fires exactly once after first render

app "S6 — on_start: Async Fetch on Mount" do
  on_start do
    # Simulated network fetch — replace with fetch_json("/api/items") in a real app
    %x{
      setTimeout(function() {
        #{state[:items] = ["Dashboard Report", "Weekly Summary", "Q2 Forecast", "Team Updates", "Release Notes"]};
      }, 800);
    }
  end

  if state[:items]
    badge "Loaded via on_start", color: :green
    div(style: "height:8px")
    state[:items].each { |item| text "• #{item}" }
  else
    text "Loading..."
  end
end
