#!/usr/bin/env ruby
# frozen_string_literal: true

# FAC-P5.1 early-gate rebuild: Rivet's People screen slice (see
# gsd/analysis/07-parity-early-gate.md for the parity assessment).
# Fixture data only -- invented names, no real Rivet records.
# Run: ruby examples/parity/rivet_people_slice.rb

require_relative "../../lib/stream_weaver"
require "date"

# ---------------------------------------------------------------------------
# Data: pure, framework-free module (mirrors rivet's Rivet::Web::Data --
# 02-sinatra-phlex-patterns.md pattern 8). Health is *derived* from
# last_touch, never stored directly -- same as rivet's health_status.
# ---------------------------------------------------------------------------
module PeopleData
  TAG_VOCAB = %w[Family Friend Colleague Investor Mentor Neighbor].freeze

  module_function

  def health_status(last_touch)
    return "red" unless last_touch
    days = (Date.today - last_touch).to_i
    return "red" if days > 30
    return "yellow" if days > 7
    "green"
  end

  def health_label(status)
    { "green" => "In touch", "yellow" => "Cooling", "red" => "Overdue" }.fetch(status)
  end

  def health_tone(status)
    { "green" => :success, "yellow" => :muted, "red" => :error }.fetch(status)
  end

  def relative_days(date)
    return "never" unless date
    days = (Date.today - date).to_i
    return "today" if days.zero?
    "#{days}d ago"
  end

  def filtered(people, query)
    q = query.to_s.strip.downcase
    return people if q.empty?
    people.select do |p|
      p[:name].downcase.include?(q) ||
        p[:relationship].to_s.downcase.include?(q) ||
        Array(p[:tags]).any? { |t| t.downcase.include?(q) }
    end
  end
end

# ---------------------------------------------------------------------------
# Store: in-memory, DB-shaped (all/find/update/touch!) -- records live here,
# never in the state hash (benchmark methodology note, 00-analysis-and-plan.md
# "Fixed Rivet + Tyrion fixtures (store-backed -- records NEVER in the state
# hash; the first run measured the state-abuse anti-pattern by mistake)").
# ---------------------------------------------------------------------------
module PeopleStore
  FIRST_NAMES = %w[Nora Milo Priya Declan Yara Finn Amara Soren Talia Bram
                    Ines Cyrus Wren Odette Kai Marisol Theo Anya Rasmus Junia
                    Emrys Selby Iris Callum Nadia Osric Vesper Lior Petra Dashiell].freeze
  LAST_NAMES = %w[Albrecht Fenwick Osei Vance Kowalczyk Larimer Thistlewood
                  Hargrove Beaumont Castellan].freeze
  RELATIONSHIPS = ["College friend", "Former colleague", "Neighbor", "Mentor",
                   "Investor", "Family", "Conference contact", "Book club"].freeze
  # Deterministic day-offsets since last touch, spread across green/yellow/red/never.
  OFFSETS = [1, 3, 45, 9, 0, 60, 5, 22, 2, 90, 4, 15, 33, 7, 1, 50, 8, 28, 3, 70,
             6, 40, 12, 2, 25, 55, 9, 18, 3, 80].freeze

  @people = Array.new(30) do |i|
    {
      id: i + 1,
      name: "#{FIRST_NAMES[i]} #{LAST_NAMES[i % LAST_NAMES.size]}",
      relationship: RELATIONSHIPS[i % RELATIONSHIPS.size],
      last_touch: OFFSETS[i].zero? ? Date.today : Date.today - OFFSETS[i],
      mentions: (i * 3) % 12,
      tags: PeopleData::TAG_VOCAB.values_at(i % 6, (i + 2) % 6).uniq
    }
  end

  class << self
    attr_reader :people

    def all = @people
    def find(id) = @people.find { |p| p[:id] == id.to_i }

    def touch!(id)
      find(id)&.merge!(last_touch: Date.today)
    end

    def update(id, attrs)
      find(id)&.merge!(attrs)
    end
  end
end

App = app "Rivet People (parity slice)" do
  header1 "People"
  text "#{PeopleStore.all.size} people", tone: :muted

  fragment(:flash) { flash_messages }

  # Named actions must be registered before any fragment/button references
  # them by name -- the DSL block runs top-to-bottom.
  #
  # Row-granular swap: Touch mutates one row in PeopleStore and is provably
  # row-local (same row order/count), so InteractionRunner narrows the
  # response to that one <tr> instead of the whole :people fragment.
  action(:touch) { |_state, key| PeopleStore.touch!(key) }

  # flash isn't listed in updates: -- a fragment named :flash auto-delivers
  # as an OOB swap whenever a scoped response sets one (stream_weaver-m3t).
  action(:save_edit, updates: :people) do |state, _key|
    person = PeopleStore.find(state[:editing_id])
    name = state[:edit_name].to_s.strip

    if name.empty?
      flash[:error] = "Name can't be blank."
    else
      PeopleStore.update(person[:id], name: name,
                                       relationship: state[:edit_relationship].to_s,
                                       tags: Array(state[:edit_tags]))
      state[:editing_id] = nil
      state[:quick_edit_open] = false
      flash[:notice] = "Saved #{name}."
    end
  end

  fragment(:people) do
    text_field :query, placeholder: "Search name, relationship, tag...",
                        debounce: 250, label: "Search"

    filtered = PeopleData.filtered(PeopleStore.all, state[:query])

    table filtered, row_key: ->(p) { p[:id] } do
      column :name
      column :relationship, header: "Relation"
      column(:health, header: "Health") do |p|
        status = PeopleData.health_status(p[:last_touch])
        text PeopleData.health_label(status), tone: PeopleData.health_tone(status)
      end
      column(:last_touch, header: "Last") { |p| PeopleData.relative_days(p[:last_touch]) }
      column :mentions, header: "Ment."
      column(:actions, header: "") do |p|
        hstack(spacing: :xs) do
          button "Touch", action: :touch, key: p[:id]
          button "Edit", key: p[:id], updates: :quick_edit_modal do |s|
            s[:editing_id] = p[:id]
            s[:edit_name] = p[:name]
            s[:edit_relationship] = p[:relationship]
            s[:edit_tags] = p[:tags].dup
          end
        end
      end
    end
  end

  fragment(:quick_edit_modal) do
    if state[:editing_id]
      open_modal(:quick_edit)
      modal(:quick_edit, title: "Quick edit") do
        text_field :edit_name, label: "Name", submit: false
        text_field :edit_relationship, label: "Relationship", submit: false
        chip_group :edit_tags, PeopleData::TAG_VOCAB, multi: true, submit: false

        modal_footer do
          button "Save", action: :save_edit, key: :save, style: :primary
          button "Cancel", key: :cancel do |s|
            s[:editing_id] = nil
            close_modal(:quick_edit)
          end
        end
      end
    end
  end
end

App.run! if __FILE__ == $0
