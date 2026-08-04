#!/usr/bin/env ruby
# frozen_string_literal: true

# Todo list with due dates -- exercises date_field inside a `form` block
# (stream_weaver-nvu): title + due date submit together as one payload, and
# the due date correctly lands in state[:new_task][:due_on] rather than
# leaking into a flat top-level key.
# Run: ruby examples/components/todo_due_dates.rb

require_relative '../../lib/stream_weaver'
require 'securerandom'

App = app "Todo List with Due Dates" do
  header1 "📝 Todo List"
  md "`date_field` inside a `form` block: title + due date submit together."

  state[:tasks] ||= []

  header2 "Add a task"
  form :new_task do
    text_field :title, placeholder: "What needs doing?"
    date_field :due_on, label: "Due date", min: Date.today.iso8601

    submit "Add Task" do |form_values|
      title = form_values[:title].to_s.strip
      next if title.empty?

      state[:tasks] << { id: SecureRandom.uuid, title: title, due_on: form_values[:due_on] }
      state[:new_task] = { title: "", due_on: "" }
    end
  end

  header2 "Tasks (#{state[:tasks].length})"

  if state[:tasks].empty?
    text "No tasks yet -- add one above.", tone: :muted
  else
    sorted_tasks = state[:tasks].sort_by do |task|
      due = StreamWeaver::Components::DateField.to_date(task[:due_on])
      [due ? 0 : 1, due || Date.new(9999, 12, 31)]
    end

    sorted_tasks.each do |task|
      due = StreamWeaver::Components::DateField.to_date(task[:due_on])
      overdue = due && due < Date.today

      div class: "todo-item" do
        text task[:title]
        if due
          text "Due #{due.iso8601}#{overdue ? ' (overdue)' : ''}", tone: overdue ? :error : :muted
        else
          text "No due date", tone: :muted
        end
        # key: a stable per-task id, so reordering by due date can't misroute the click
        button "✓", key: task[:id], style: :secondary do |s|
          s[:tasks].reject! { |t| t[:id] == task[:id] }
        end
      end
    end
  end
end

App.run! if __FILE__ == $0
