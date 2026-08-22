# frozen_string_literal: true

# In-memory stores for the My Todos parity spike.
#
# Mirrors the learnhotwire.com course app's `Todo` / `User` models closely
# enough to exercise the same four Turbo Frames chapter features:
# `Todo.search(query)` (including the blank guard the chapter demos as a live
# bug), a `user_id` assignee for hover cards, and enough rows to paginate.

module UserStore
  USERS = {
    'u1' => { id: 'u1', name: 'Ada Lovelace',  role: 'Engineering', joined: '2024-03-11' },
    'u2' => { id: 'u2', name: 'Alan Turing',   role: 'Research',    joined: '2023-11-02' },
    'u3' => { id: 'u3', name: 'Grace Hopper',  role: 'Platform',    joined: '2025-01-20' }
  }.freeze

  def self.all = USERS.values
  def self.find(id) = USERS[id]

  # Deliberately slow, to make "was this fetched lazily or eagerly?" observable
  # the way the chapter's `sleep 1.5` does in the Rails app. Off by default so
  # the spike app stays usable; set SW_HOVERCARD_DELAY=1.5 to feel the cost of
  # rendering every card eagerly.
  def self.delay
    seconds = ENV['SW_HOVERCARD_DELAY'].to_f
    sleep(seconds) if seconds.positive?
  end
end

module TodoStore
  TITLES = [
    'Buy milk', 'Ship the parity spike', 'Review the fragment docs',
    'Book the offsite', 'Refactor the store protocol', 'Write release notes',
    'Answer the support thread', 'Update the changelog', 'Prune stale branches',
    'Draft the design memo', 'Pair on the routing bug', 'Buy coffee beans'
  ].freeze

  @todos = 60.times.map do |i|
    {
      id: (i + 1).to_s,
      title: "#{TITLES[i % TITLES.length]} ##{i + 1}",
      completed: (i % 5).zero?,
      user_id: "u#{(i % 3) + 1}"
    }
  end

  class << self
    def all = @todos
    def find(id) = @todos.find { |t| t[:id] == id.to_s }

    def create(attrs)
      id = ((@todos.map { |t| t[:id].to_i }.max || 0) + 1).to_s
      @todos << { id: id, completed: false, user_id: 'u1', **attrs }
      id
    end

    def update(id, attrs)
      todo = find(id) or return false
      todo.merge!(attrs)
      true
    end

    def destroy(id)
      @todos.reject! { |t| t[:id] == id.to_s }
      true
    end

    # Mirrors the course's `Todo.search`, blank guard included. The chapter
    # demos the missing-guard version as a live bug: clear the box and the
    # whole list vanishes because the LIKE runs against nil.
    def search(query)
      return all if query.to_s.strip.empty?
      needle = query.to_s.downcase
      all.select { |t| t[:title].downcase.include?(needle) }
    end

    # Cumulative pages, `1..page`, because StreamWeaver has no nested-frame
    # append -- see docs/research/streamweaver-way-spike-findings.md, feature 4.
    def through_page(page, per_page: 10)
      all.first([page.to_i, 1].max * per_page)
    end

    def page_count(per_page: 10) = (all.length / per_page.to_f).ceil
  end
end
