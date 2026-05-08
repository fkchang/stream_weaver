# frozen_string_literal: true
# S9: Dashboard — Multiple Widgets Sharing One Symbol
# React equivalent: Context API + multiple connected components
# StreamWeaver: state[:symbol] is just there — every widget reads it directly

app "S9 — Dashboard: Multiple Widgets, Shared Symbol" do
  prices  = { "AAPL" => 189.30, "MSFT" => 378.85, "GOOG" => 140.53 }
  volumes = { "AAPL" => "54.2M", "MSFT" => "22.1M", "GOOG" => "28.7M" }
  pes     = { "AAPL" => 29.4,    "MSFT" => 35.2,    "GOOG" => 26.1   }

  sym = state[:symbol] || "AAPL"

  # Symbol selector — buttons (safe across all Opal adapters)
  text "Select symbol:"
  %w[AAPL MSFT GOOG].each do |s|
    button(s) { state[:symbol] = s }
  end

  div(style: "height:16px")

  # Try columns layout
  columns widths: ["33%", "33%", "34%"] do
    column { card { header3 "Price";  text "$#{prices[sym]}"  } }
    column { card { header3 "Volume"; text volumes[sym]        } }
    column { card { header3 "P/E";    text pes[sym].to_s       } }
  end
end
