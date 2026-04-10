#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../../lib/stream_weaver'

# Inline GoalStore — hardcoded fixtures, no YAML file dependencies
module GoalStore
  @goals = [
    { id: '1', title: 'Ship Resource DSL',    horizon: 'month' },
    { id: '2', title: 'Launch UTF Dashboard', horizon: 'quarter' },
    { id: '3', title: 'Automate SDRD cycle',  horizon: 'year' }
  ]

  def self.all;      @goals; end
  def self.find(id); @goals.find { |g| g[:id] == id }; end

  def self.create(attrs)
    id = ((@goals.map { |g| g[:id].to_i }.max || 0) + 1).to_s
    @goals << { id: id, **attrs }
    id
  end

  def self.update(id, attrs)
    goal = find(id) or return false
    goal.merge!(attrs)
    true
  end

  def self.destroy(id)
    @goals.reject! { |g| g[:id] == id }
    true
  end
end

# Inline InitiativeStore — hardcoded fixtures, no YAML file dependencies
module InitiativeStore
  @initiatives = [
    { id: '1', title: 'Write resource DSL specs', status: 'active',    horizon: 'month' },
    { id: '2', title: 'Build UTF Lite example',   status: 'active',    horizon: 'month' },
    { id: '3', title: 'Playwright smoke tests',   status: 'paused',    horizon: 'quarter' }
  ]

  def self.all;      @initiatives; end
  def self.find(id); @initiatives.find { |i| i[:id] == id }; end

  def self.create(attrs)
    id = ((@initiatives.map { |i| i[:id].to_i }.max || 0) + 1).to_s
    @initiatives << { id: id, **attrs }
    id
  end

  def self.update(id, attrs)
    initiative = find(id) or return false
    initiative.merge!(attrs)
    true
  end

  def self.destroy(id)
    @initiatives.reject! { |i| i[:id] == id }
    true
  end
end

app 'UTF Lite', layout: :wide, theme: :dashboard do
  resource :goal, store: GoalStore do
    field :title,   :string
    field :horizon, :enum, values: %w[month quarter year]

    index do |goals|
      header1 'Goals'
      goals.group_by { |g| g[:horizon] }.each do |horizon, gs|
        header3 horizon.to_s.capitalize
        table gs do
          column :title
          column(:actions) do |g|
            button('Open') do |s|
              s[:_sw_action]   = :show
              s[:_sw_resource] = :goal
              s[:_sw_id]       = g[:id]
            end
          end
        end
      end
    end
  end

  resource :initiative, store: InitiativeStore do
    field :title,   :string
    field :status,  :enum, values: %w[active paused completed]
    field :horizon, :string
    edit_view :page
  end

  navbar do
    nav_item 'Home',        href: '/',             active: state[:_sw_action] == :home
    nav_item 'Goals',       href: '/goals',        active: state[:_sw_resource] == :goal
    nav_item 'Initiatives', href: '/initiatives',  active: state[:_sw_resource] == :initiative
  end

  page :home, '/' do
    header1 'UTF Dashboard Lite'
    columns widths: ['50%', '50%'] do
      column { card { header3 'Goals';       text "#{GoalStore.all.size} tracked" } }
      column { card { header3 'Initiatives'; text "#{InitiativeStore.all.size} active" } }
    end
  end
end.run!
