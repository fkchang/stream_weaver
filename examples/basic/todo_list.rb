#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/stream_weaver'

# Full CRUD Todo List App
App = app "Todo Manager" do
  header "📝 Todo List"

  text_field :new_todo, placeholder: "Enter a new todo"

  button "Add Todo" do |state|
    state[:todos] ||= []
    if state[:new_todo] && state[:new_todo].strip != ""
      state[:todos] << state[:new_todo]
      state[:new_todo] = ""
    end
  end

  # Display todos
  state[:todos] ||= []

  if state[:todos].empty?
    text "No todos yet. Add one above!"
  else
    header3 "Your Todos (#{state[:todos].length})"

    state[:todos].each_with_index do |todo, idx|
      div class: "todo-item" do
        text todo
        button "✓", style: :secondary do |state|
          state[:todos].delete_at(idx)
        end
      end
    end
  end
end

App.run! if __FILE__ == $0
