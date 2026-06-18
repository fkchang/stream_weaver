# Usage: streamweaver canvas-push <session> < examples/components/diff_block_demo.rb
# Or:    streamweaver panel diff-block-demo && streamweaver canvas-push diff-block-demo < examples/components/diff_block_demo.rb

header2 "DiffBlock — Unified Diff Viewer"
md "Server-side diff via diffy gem. Removed lines red, added lines green, context neutral. Two-column line-number gutter. Prism.js syntax highlighting per line."

header3 "Ruby method refactor"

diff(language: "ruby") do
  before do
    <<~'RUBY'
      def greet
        puts 'hi'
      end
    RUBY
  end
  after do
    <<~'RUBY'
      def greet(name)
        puts "Hello, #{name}"
      end
    RUBY
  end
end

header3 "Multi-hunk diff (large file excerpt)"

diff(language: "ruby") do
  before do
    <<~'RUBY'
      class User
        attr_reader :name, :email

        def initialize(name, email)
          @name  = name
          @email = email
        end

        def display
          "#{name} <#{email}>"
        end

        def active?
          true
        end
      end
    RUBY
  end
  after do
    <<~'RUBY'
      class User
        attr_reader :name, :email, :role

        def initialize(name, email, role: :viewer)
          @name  = name
          @email = email
          @role  = role
        end

        def display
          "#{name} <#{email}> [#{role}]"
        end

        def active?
          @role != :suspended
        end
      end
    RUBY
  end
end

header3 "JavaScript"

diff(language: "javascript") do
  before do
    <<~JS
      function fetchUser(id) {
        return fetch('/users/' + id)
          .then(function(res) { return res.json(); });
      }
    JS
  end
  after do
    <<~JS
      async function fetchUser(id) {
        const res = await fetch(`/users/${id}`);
        return res.json();
      }
    JS
  end
end

header3 "No language (plain text / pseudocode)"

diff do
  before do
    <<~TEXT
      push start onto stack
      while stack not empty
        node = stack.pop
        visit node
    TEXT
  end
  after do
    <<~TEXT
      enqueue start
      while queue not empty
        node = queue.dequeue
        visit node
    TEXT
  end
end
