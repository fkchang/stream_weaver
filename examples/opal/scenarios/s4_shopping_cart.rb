# frozen_string_literal: true
# S4: Shopping Cart with Derived Total
# React equivalent: Context API (or Redux/Zustand) to share cart across component trees
# StreamWeaver: state[:cart] is already visible everywhere — no Context needed

app "S4 — Shopping Cart" do
  products = [
    { name: "Widget",    price: 9.99  },
    { name: "Gadget",    price: 24.99 },
    { name: "Doohickey", price: 4.99  },
  ]

  products.each do |p|
    card do
      header3 p[:name]
      text "$#{p[:price]}"
      button("Add to cart") { state[:cart] = (state[:cart] || []) + [p] }
    end
  end

  div(style: "height:16px")

  cart = state[:cart] || []
  card do
    header3 "Cart (#{cart.size} items)"
    if cart.empty?
      text "Nothing added yet"
    else
      cart.each { |item| text "• #{item[:name]} — $#{item[:price]}" }
      text "Total: $#{"%.2f" % cart.sum { |i| i[:price] }}"
      button("Clear") { state[:cart] = [] }
    end
  end
end
