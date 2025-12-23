#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Todo List with Database Persistence
# 
# This example demonstrates how to use StreamWeaver with a database
# for persistent storage instead of session-based state.
#
# Setup:
#   gem install stream_weaver sinatra-activerecord sqlite3 rake
#   
# Create migration:
#   bundle exec rake db:create_migration NAME=create_todos
#   
# Add to migration:
#   create_table :todos do |t|
#     t.string :text
#     t.boolean :completed, default: false
#     t.timestamps
#   end
#   
# Run migration:
#   bundle exec rake db:migrate
#   
# Run:
#   ruby examples/database_todo.rb

require_relative '../lib/stream_weaver'
require 'sinatra/activerecord'

# Database configuration
configure :development do
  set :database, {adapter: 'sqlite3', database: 'db/todos_dev.db'}
end

configure :production do
  set :database, ENV['DATABASE_URL'] || {adapter: 'sqlite3', database: 'db/todos_prod.db'}
end

# Todo model
class Todo < ActiveRecord::Base
  validates :text, presence: true
  
  scope :active, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }
end

# Create table if it doesn't exist (for quick demo purposes)
# In production, use proper migrations
unless ActiveRecord::Base.connection.table_exists?(:todos)
  ActiveRecord::Base.connection.create_table :todos do |t|
    t.string :text
    t.boolean :completed, default: false
    t.timestamps
  end
end

# StreamWeaver App
App = app "📝 Todo Manager (Database)" do
  header1 "Todo Manager"
  text "Todos are persisted to SQLite database"
  
  # Add new todo
  text_field :new_todo, placeholder: "What needs to be done?"
  
  button "Add Todo" do |state|
    if state[:new_todo] && !state[:new_todo].strip.empty?
      Todo.create(text: state[:new_todo])
      state[:new_todo] = ""
    end
  end
  
  # Stats
  active_count = Todo.active.count
  completed_count = Todo.completed.count
  
  card do
    hstack justify: :between do
      text "📊 Active: #{active_count}"
      text "✅ Completed: #{completed_count}"
    end
  end
  
  # Filter tabs
  tabs :filter do
    tab "Active" do
      todos = Todo.active.order(created_at: :desc)
      
      if todos.empty?
        text "No active todos. Add one above!"
      else
        todos.each do |todo|
          card do
            hstack justify: :between do
              text todo.text
              hstack spacing: :sm do
                button "✓ Complete", style: :secondary do |state|
                  todo.update(completed: true)
                end
                button "🗑 Delete", style: :secondary do |state|
                  todo.destroy
                end
              end
            end
          end
        end
      end
    end
    
    tab "Completed" do
      todos = Todo.completed.order(updated_at: :desc)
      
      if todos.empty?
        text "No completed todos yet"
      else
        todos.each do |todo|
          card do
            hstack justify: :between do
              text "~~#{todo.text}~~"
              hstack spacing: :sm do
                button "↩ Reopen", style: :secondary do |state|
                  todo.update(completed: false)
                end
                button "🗑 Delete", style: :secondary do |state|
                  todo.destroy
                end
              end
            end
          end
        end
      end
    end
    
    tab "All" do
      todos = Todo.order(created_at: :desc)
      
      if todos.empty?
        text "No todos yet"
      else
        todos.each do |todo|
          card do
            hstack justify: :between do
              text todo.completed ? "~~#{todo.text}~~" : todo.text
              hstack spacing: :sm do
                if todo.completed
                  button "↩ Reopen", style: :secondary do |state|
                    todo.update(completed: false)
                  end
                else
                  button "✓ Complete", style: :secondary do |state|
                    todo.update(completed: true)
                  end
                end
                button "🗑 Delete", style: :secondary do |state|
                  todo.destroy
                end
              end
            end
          end
        end
      end
    end
  end
end

App.run! if __FILE__ == $0
