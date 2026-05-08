# frozen_string_literal: true
# S2: Search-Filtered List
# React equivalent: useMemo with [search] dependency array
# StreamWeaver: inline computation — the filter IS the render

app "S2 — Search-Filtered List" do
  text_field :search, placeholder: "Filter fruits..."

  fruits = %w[Apple Apricot Avocado Banana Blueberry Cherry Cranberry Date Elderberry Fig Grape Kiwi]
  query  = state[:search].to_s.downcase
  items  = query.empty? ? fruits : fruits.select { |f| f.downcase.include?(query) }

  text "#{items.size} of #{fruits.size} shown"
  div do
    items.each { |fruit| text fruit }
  end
end
