# frozen_string_literal: true
# S5: Watch — Side Effect on State Change
# React equivalent: useEffect with [search] dependency array
# StreamWeaver: watch(:key) { |val| } — fires only when that key changes

app "S5 — Watch: Side Effect on State Change" do
  watch(:search_query) do |query|
    corpus = %w[Apple Apricot Avocado Banana Blueberry Cherry Cranberry
                Date Elderberry Fig Grape Kiwi Lemon Lime Mango]
    state[:results] = query.to_s.strip.empty? ? corpus : corpus.select { |f| f.downcase.include?(query.downcase) }
  end

  text_field :search_query, placeholder: "Type to search..."

  results = state[:results] || %w[Apple Apricot Avocado Banana Blueberry Cherry Cranberry Date Elderberry Fig Grape Kiwi Lemon Lime Mango]
  text "#{results.size} results"
  results.each { |r| text r }
end
