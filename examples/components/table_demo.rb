# frozen_string_literal: true

# Demo of the Table component with all features
# Run: ruby examples/components/table_demo.rb
# Open: http://localhost:4567

require_relative '../../lib/stream_weaver'

# Sample data for demos
USERS = [
  { name: "Alice Johnson", email: "alice@example.com", balance: 1234.56, joined: Date.new(2024, 3, 15), active: true },
  { name: "Bob Smith", email: "bob@example.com", balance: 567.89, joined: Date.new(2024, 6, 22), active: true },
  { name: "Carol Davis", email: "carol@example.com", balance: 89012.34, joined: Date.new(2023, 11, 1), active: false },
  { name: "Dan Wilson", email: "dan@example.com", balance: 234.00, joined: Date.new(2025, 1, 5), active: true }
].freeze

METRICS = {
  month: %w[Jan Feb Mar Apr May Jun],
  revenue: [45000, 52000, 48000, 61000, 55000, 67000],
  users: [120, 145, 132, 178, 165, 203]
}.freeze

app "Table Component Demo", layout: :wide do
  header "Table Component - All Features"
  text "Demonstrating the enhanced table component with smart data inference, formatters, and interactive features."

  tabs :demo_tabs do
    # Tab 1: Basic Usage
    tab "Basic" do
      vstack spacing: :lg do
        card do
          header3 "Original API"
          text "The original headers/rows API still works:"

          table headers: ["Name", "Role", "Status"],
                rows: [
                  ["Alice", "Engineer", "Active"],
                  ["Bob", "Designer", "Active"],
                  ["Carol", "Manager", "On Leave"]
                ],
                striped: true
        end

        card do
          header3 "Array of Hashes (Auto-Infer Headers)"
          text "Pass an array of hashes - headers are inferred from keys:"

          table [
            { name: "Alice", role: "Engineer", department: "Platform" },
            { name: "Bob", role: "Designer", department: "Product" },
            { name: "Carol", role: "Manager", department: "Engineering" }
          ], striped: true
        end

        card do
          header3 "Hash of Arrays"
          text "Pass a hash where keys are columns and values are arrays:"

          table METRICS, striped: true, compact: true
        end
      end
    end

    # Tab 2: Column DSL with Formatters
    tab "Formatters" do
      vstack spacing: :lg do
        card do
          header3 "Column DSL with Built-in Formatters"
          text "Define columns with formatting and alignment:"

          table USERS do
            column :name
            column :email, header: "E-mail"
            column :balance, format: :currency, align: :right
            column :joined, header: "Join Date", format: :date
            column(:active) { |u| u[:active] ? "Yes" : "No" }
          end
        end

        card do
          header3 "Available Formatters"
          table headers: ["Formatter", "Input", "Output"],
                rows: [
                  [":date", "Date.today", Date.today.strftime("%b %d, %Y")],
                  [":datetime", "Time.now", Time.now.strftime("%b %d, %Y %l:%M %p")],
                  [":currency", "1234.56", "$1,234.56"],
                  [":number", "1234567", "1,234,567"],
                  [":percent", "0.42", "42%"]
                ],
                bordered: true, compact: true
        end

        card do
          header3 "Custom Formatter (Proc)"
          text "Use a Proc for custom formatting logic:"

          table USERS do
            column :name
            column :balance, format: ->(v) { v > 1000 ? "#{(v/1000.0).round(1)}k" : v.to_s }, align: :right
            column(:status) { |u| u[:active] ? "Active" : "Inactive" }
          end
        end
      end
    end

    # Tab 3: Interactive Features
    tab "Interactive" do
      vstack spacing: :lg do
        card do
          header3 "Sortable Table"
          text "Click column headers to sort. Handles both text and numeric sorting:"

          table [
            { product: "Widget A", price: 29.99, quantity: 150, revenue: 4498.50 },
            { product: "Widget B", price: 49.99, quantity: 75, revenue: 3749.25 },
            { product: "Widget C", price: 19.99, quantity: 300, revenue: 5997.00 },
            { product: "Widget D", price: 99.99, quantity: 25, revenue: 2499.75 }
          ], sortable: true, striped: true
        end

        card do
          header3 "Sticky Header (Scroll to See)"
          text "Header stays visible when scrolling long tables:"

          # Generate more rows for scrolling demo
          many_rows = (1..20).map do |i|
            { id: i, name: "Item #{i}", category: %w[A B C].sample, value: rand(100..999) }
          end

          table many_rows, sticky_header: true, striped: true, compact: true
        end

        card do
          header3 "Combined: Sortable + Sticky"

          table USERS + USERS + USERS do
            column :name
            column :balance, format: :currency, align: :right
            column :joined, format: :date
          end
        end
      end
    end

    # Tab 4: Data Sources
    tab "Data Sources" do
      vstack spacing: :lg do
        card do
          header3 "State Binding"
          text "Table reads from state - updates when state changes:"

          state[:dynamic_items] ||= [
            { item: "Apple", count: 5 },
            { item: "Banana", count: 3 },
            { item: "Cherry", count: 8 }
          ]

          table data: :dynamic_items, striped: true

          hstack spacing: :sm do
            button "Add Random Item" do |s|
              fruits = %w[Mango Orange Grape Kiwi Peach]
              s[:dynamic_items] << { item: fruits.sample, count: rand(1..10) }
            end

            button "Clear", style: :secondary do |s|
              s[:dynamic_items] = []
            end
          end
        end

        card do
          header3 "File Loading"
          text "Load data from YAML or JSON files (like charts):"
          md "`table file: \"data/users.yaml\", path: \"users\"`"
          text "The file: and path: options work exactly like charts."
        end

        card do
          header3 "Transform Block"
          text "Process file data before display:"
          md <<~MD
            ```ruby
            table file: "raw_data.yaml" do |data|
              data.map { |r| { name: r[:n], value: r[:v] } }
            end
            ```
          MD
        end

        card do
          header3 "Markdown Links"
          text "Enable clickable links in cells with markdown: true:"

          table [
            { issue: "[PROJ-101](https://example.com/issues/101)", title: "Fix login bug", status: "Open" },
            { issue: "[PROJ-102](https://example.com/issues/102)", title: "Add dark mode", status: "In Progress" },
            { issue: "[PROJ-103](https://example.com/issues/103)", title: "Update docs", status: "Closed" }
          ], markdown: true, striped: true

          text "Without markdown: true, links show as literal text."
        end
      end
    end

    # Tab 5: Styling
    tab "Styling" do
      columns do
        column do
          card do
            header4 "Default"
            table [{ a: 1, b: 2 }, { a: 3, b: 4 }]
          end

          card do
            header4 "Striped"
            table [{ a: 1, b: 2 }, { a: 3, b: 4 }, { a: 5, b: 6 }], striped: true
          end

          card do
            header4 "Bordered"
            table [{ a: 1, b: 2 }, { a: 3, b: 4 }], bordered: true
          end
        end

        column do
          card do
            header4 "Compact"
            table [{ a: 1, b: 2 }, { a: 3, b: 4 }], compact: true
          end

          card do
            header4 "With Caption"
            table [{ a: 1, b: 2 }, { a: 3, b: 4 }], caption: "Sample Data"
          end

          card do
            header4 "All Options"
            table [{ a: 1, b: 2 }, { a: 3, b: 4 }, { a: 5, b: 6 }],
                  striped: true, bordered: true, compact: true,
                  caption: "Full Style Demo"
          end
        end
      end
    end
  end
end.run!
