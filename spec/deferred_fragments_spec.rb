# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "cgi"

RSpec.describe "deferred fragments" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  def render(app, state = {})
    app.rebuild_with_state(state, generation: "defer-session")
    StreamWeaver::Views::AppContentView.new(app, state, adapter, false).call
  end

  # The fragment-scoped fetch URL the deferred placeholder emits, unescaped the
  # way a browser would send it.
  def deferred_path(html, fragment_id)
    wrapper = html[/<div[^>]+hx-trigger="load"[^>]*>/] or raise "no deferred wrapper in #{html}"
    raise "wrapper does not target ##{fragment_id}" unless wrapper.include?(%(hx-target="##{fragment_id}"))
    CGI.unescapeHTML(wrapper[/hx-post="([^"]+)"/, 1])
  end

  describe "shell render" do
    it "renders the placeholder without executing the deferred block" do
      executed = false
      app = StreamWeaver::App.new("Deferred") do
        fragment(:stats, defer: true, placeholder: "Loading stats…") do
          executed = true
          text "REAL STATS"
        end
        text "FAST SHELL"
      end

      html = render(app)

      expect(executed).to be(false)
      expect(html).to include("FAST SHELL", "Loading stats…", 'id="sw-frag-stats"')
      expect(html).not_to include("REAL STATS")
    end

    it "defaults to a spinner placeholder when none is given" do
      app = StreamWeaver::App.new("Default placeholder") do
        fragment(:stats, defer: true) { text "REAL STATS" }
      end

      html = render(app)

      expect(html).to include("sw-spinner")
      expect(html).not_to include("REAL STATS")
    end

    it "accepts a DSL proc placeholder" do
      app = StreamWeaver::App.new("Proc placeholder") do
        fragment(:stats, defer: true, placeholder: -> { text "CUSTOM SKELETON" }) do
          text "REAL STATS"
        end
      end

      expect(render(app)).to include("CUSTOM SKELETON")
    end

    it "emits an auto-fetch trigger with a signed fragment token and no app JavaScript" do
      app = StreamWeaver::App.new("Auto fetch") do
        fragment(:stats, defer: true) { text "REAL STATS" }
      end

      html = render(app)
      wrapper = html[/<div[^>]+hx-trigger="load"[^>]*>/]

      expect(wrapper).to include('hx-target="#sw-frag-stats"', 'hx-swap="morph:innerHTML"',
                                 'hx-include="[x-model]"')
      # The whole fetch is declarative attributes: the only script tag in the
      # body is the framework's own JSON state carrier, never executable code.
      expect(html.scan(/<script[^>]*>/)).to all(include('type="application/json"'))

      token = CGI.unescape(wrapper[/_sw_fragment=([^"&]+)/, 1])
      expect(StreamWeaver::ActionToken.decode(token)).to include(f: "sw-frag-stats")
    end

    # The auto-fetch attributes ride an inner wrapper with an id of its own so a
    # full-container morph replaces it rather than matching materialized content
    # against it positionally and reusing an already-initialized element. A
    # deferred fragment that lost this would refetch on the reused element; a
    # `lazy: true` one would sit on its placeholder forever, since htmx's `once`
    # latch lives in that element's internal data.
    it "wraps the auto-fetch in an element with its own id" do
      app = StreamWeaver::App.new("Wrapper id") { fragment(:stats, defer: true) { text "REAL STATS" } }

      expect(render(app)).to include('id="sw-frag-stats--deferred"')
    end

    it "leaves non-deferred fragments executing inline" do
      app = StreamWeaver::App.new("Mixed") do
        fragment(:eager) { text "EAGER BODY" }
        fragment(:slow, defer: true) { text "SLOW BODY" }
      end

      html = render(app)

      expect(html).to include("EAGER BODY")
      expect(html).not_to include("SLOW BODY")
      expect(html.scan('hx-trigger="load"').length).to eq(1)
    end
  end

  describe "deferred fetch" do
    it "executes the block and returns just that fragment's content" do
      app = StreamWeaver::App.new("Fetch") do
        fragment(:stats, defer: true, placeholder: "Loading…") { text "REAL STATS" }
        text "UNRELATED PAGE COPY"
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body

      response = session.post(deferred_path(html, "sw-frag-stats"))

      expect(response.status).to eq(200)
      expect(response.body).to include("REAL STATS")
      expect(response.body).not_to include("UNRELATED PAGE COPY", "Loading…")
    end

    it "renders the fetched fragment from current session state" do
      app = StreamWeaver::App.new("Stateful") do
        text_field :q
        fragment(:stats, defer: true) { text "matched #{state[:q]}" }
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body

      response = session.post(deferred_path(html, "sw-frag-stats"), "q" => "milk")

      expect(response.body).to include("matched milk")
    end

    it "keeps other deferred fragments deferred on a deferred fetch" do
      app = StreamWeaver::App.new("Two deferred") do
        fragment(:one, defer: true) { text "ONE BODY" }
        fragment(:two, defer: true) { text "TWO BODY" }
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body
      wrapper = html.scan(/<div[^>]+hx-trigger="load"[^>]*>/).find { |w| w.include?("#sw-frag-two") }
      path = CGI.unescapeHTML(wrapper[/hx-post="([^"]+)"/, 1])

      response = session.post(path)

      expect(response.body).to include("TWO BODY")
      expect(response.body).not_to include("ONE BODY")
    end
  end

  describe "concurrency and state versioning" do
    # Every deferred fragment on a page fires its `load` trigger in the same
    # tick, so their requests all leave carrying the same sw_state_version
    # cookie. A patch is versioned `current + 1` and the client reloads the page
    # on any other value, so two deferred fetches both claiming the next version
    # would put the browser in a reload loop.
    it "sends no state patch with a deferred fetch" do
      app = StreamWeaver::App.new("No patch") do
        text_field :q
        fragment(:stats, defer: true) { text "REAL STATS" }
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body

      response = session.post(deferred_path(html, "sw-frag-stats"), "q" => "milk")

      expect(response.body).to include("REAL STATS")
      expect(response.body).not_to include('id="sw-state-patch"')
    end

    it "leaves the state version untouched so concurrent fetches cannot collide" do
      app = StreamWeaver::App.new("Two panels") do
        fragment(:one, defer: true) { text "ONE BODY" }
        fragment(:two, defer: true) { text "TWO BODY" }
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body
      wrappers = html.scan(/<div[^>]+hx-trigger="load"[^>]*>/)
      paths = wrappers.map { |w| CGI.unescapeHTML(w[/hx-post="([^"]+)"/, 1]) }

      bodies = paths.map { |path| session.post(path).body }

      expect(bodies.first).to include("ONE BODY")
      expect(bodies.last).to include("TWO BODY")
      expect(bodies.join).not_to include('id="sw-state-patch"')
    end

    it "still sends a versioned patch for an ordinary fragment update" do
      app = StreamWeaver::App.new("Ordinary") do
        fragment(:search) do
          text_field :query
          text "results for #{state[:query]}"
        end
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body
      input = html[/<input[^>]+name="query"[^>]*>/]

      response = session.post(CGI.unescapeHTML(input[/hx-post="([^"]+)"/, 1]), "query" => "Ada")

      expect(response.body).to include("results for Ada", 'id="sw-state-patch"')
    end
  end

  # KNOWN LIMITATION, locked here so a fix is a deliberate, visible change.
  # `/update` passes neither `generation:` nor `persist_manifest:`, so an action
  # token minted during a deferred fetch carries g:"0" and its fingerprint never
  # reaches the session manifest -- InteractionRunner#dispatch then declines to
  # run it. The gap is pre-existing (any /update-rendered named action has it,
  # see features/now-view-support.context.md), but `defer:` makes the deferred
  # fetch the only way that fragment's buttons are ever minted. Tracked as a
  # discovery; documented in llms.txt.
  describe "named actions inside a deferred fragment (known limitation)" do
    def counter_app(defer:)
      StreamWeaver::App.new("Counter") do
        action(:bump) { |s, _| s[:count] = s[:count].to_i + 1 }
        fragment(:panel, defer: defer) do
          text "count #{state[:count].to_i}"
          button "Bump", action: :bump, key: 1
        end
      end
    end

    it "does not execute -- the token is minted outside the session's action manifest" do
      session = Rack::Test::Session.new(Rack::MockSession.new(counter_app(defer: true).generate))
      html = session.get("/").body
      body = session.post(deferred_path(html, "sw-frag-panel")).body
      token = body[%r{/action/([^?"']+)}, 1]

      expect(StreamWeaver::ActionToken.decode(token)).to include(g: "0")
      expect(session.post("/action/#{token}").body).to include("count 0")
    end

    it "works in a non-deferred fragment, which is the behaviour the deferred one should reach" do
      session = Rack::Test::Session.new(Rack::MockSession.new(counter_app(defer: false).generate))
      token = session.get("/").body[%r{/action/([^?"']+)}, 1]

      expect(session.post("/action/#{token}").body).to include("count 1")
    end

    it "dispatches a block button, the documented workaround" do
      app = StreamWeaver::App.new("Block button") do
        fragment(:panel, defer: true) do
          text "count #{state[:count].to_i}"
          button("Bump") { |s| s[:count] = s[:count].to_i + 1 }
        end
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body
      body = session.post(deferred_path(html, "sw-frag-panel")).body

      response = session.post(CGI.unescapeHTML(body[%r{hx-post="(/action/[^"]+)"}, 1]))

      expect(response.body).to include("count 1")
    end
  end

  describe "url prefix" do
    # Service mode mounts each app under /apps/:app_id, so a hardcoded /update
    # would 404 and leave the fragment on its placeholder forever.
    it "routes the auto-fetch through the adapter's url prefix" do
      prefixed = StreamWeaver::Adapter::AlpineJS.new(url_prefix: "/apps/demo")
      app = StreamWeaver::App.new("Prefixed") { fragment(:stats, defer: true) { text "REAL STATS" } }
      app.rebuild_with_state({}, generation: "defer-session")

      html = StreamWeaver::Views::AppContentView.new(app, {}, prefixed, false).call

      expect(html).to include('hx-post="/apps/demo/update?_sw_fragment=')
    end
  end

  describe "static export" do
    it "runs deferred blocks inline, since nothing will fetch them later" do
      app = StreamWeaver::App.new("Exported") do
        text "SHELL"
        fragment(:stats, defer: true, placeholder: "Loading…") { text "REAL STATS" }
      end

      html = StreamWeaver::Export::HtmlExporter.new(app).to_html

      expect(html).to include("SHELL", "REAL STATS")
      expect(html).not_to include("Loading…", 'hx-trigger="load"')
    end
  end

  describe "authoring mistakes fail loudly" do
    it "rejects placeholder: without defer:" do
      expect {
        StreamWeaver::App.new("Oops") { fragment(:stats, placeholder: "Loading…") { text "body" } }
          .rebuild_with_state({})
      }.to raise_error(ArgumentError, /placeholder: requires defer: true/)
    end

    it "rejects the unimplemented bare `defer` verb instead of dropping its block" do
      expect {
        StreamWeaver::App.new("Stub") { defer { text "DROPPED" } }.rebuild_with_state({})
      }.to raise_error(NoMethodError, /fragment\(:name, defer: true\)/)
    end
  end

  describe "nesting" do
    it "defers a fragment nested inside a plain fragment and fetches it in place" do
      app = StreamWeaver::App.new("Nested plain") do
        fragment(:outer) do
          text "OUTER BODY"
          fragment(:inner, defer: true) { text "INNER BODY" }
        end
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body

      expect(html).to include("OUTER BODY", 'id="sw-frag-outer--inner"')
      expect(html).not_to include("INNER BODY")

      response = session.post(deferred_path(html, "sw-frag-outer--inner"))
      expect(response.body).to include("INNER BODY")
      expect(response.body).not_to include("OUTER BODY")
    end

    it "chains a deferred fragment nested inside a deferred fragment" do
      app = StreamWeaver::App.new("Nested deferred") do
        fragment(:outer, defer: true) do
          text "OUTER BODY"
          fragment(:inner, defer: true) { text "INNER BODY" }
        end
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      shell = session.get("/").body

      expect(shell).not_to include("OUTER BODY", "INNER BODY")

      outer = session.post(deferred_path(shell, "sw-frag-outer")).body
      expect(outer).to include("OUTER BODY", 'id="sw-frag-outer--inner"')
      expect(outer).not_to include("INNER BODY")

      inner = session.post(deferred_path(outer, "sw-frag-outer--inner")).body
      expect(inner).to include("INNER BODY")
      expect(inner).not_to include("OUTER BODY")
    end
  end

  describe "benchmark: a slow fragment must not delay the shell" do
    it "returns the shell fast while the fragment endpoint pays the cost" do
      app = StreamWeaver::App.new("Slow") do
        text "FAST SHELL"
        fragment(:slow, defer: true) do
          sleep 1.5
          text "SLOW BODY"
        end
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))

      shell_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      html = session.get("/").body
      shell_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - shell_started

      fetch_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      body = session.post(deferred_path(html, "sw-frag-slow")).body
      fetch_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - fetch_started

      expect(html).to include("FAST SHELL")
      expect(body).to include("SLOW BODY")
      expect(shell_elapsed).to be < 0.5
      expect(fetch_elapsed).to be >= 1.5
    end
  end

  # The spike's browser pass reported that the fragment-scoped /update path
  # renders without merging posted x-model params into state
  # (docs/research/streamweaver-way-spike-findings.md, "Main-thread browser
  # verification pass"). It does merge -- InteractionRunner#call syncs params
  # before the response rebuild for every non-form interaction. These lock that
  # in for the orderings the browser pass exercised, since the deferred fetch
  # rides the same path.
  describe "fragment-scoped param merge (spike ADDENDUM regression)" do
    def search_app
      StreamWeaver::App.new("Search") do
        text_field :query
        fragment(:outside) { text "outside:#{state[:query]}" }
        fragment(:inside) do
          text_field :query_inside
          text "inside:#{state[:query_inside]}"
        end
      end
    end

    def field_path(html, name)
      input = html[/<input[^>]+name="#{name}"[^>]*>/]
      CGI.unescapeHTML(input[/hx-post="([^"]+)"/, 1])
    end

    it "merges params posted from an input inside a fragment" do
      session = Rack::Test::Session.new(Rack::MockSession.new(search_app.generate))
      html = session.get("/").body

      response = session.post(field_path(html, "query_inside"), "query_inside" => "milk", "query" => "")

      expect(response.body).to include("inside:milk")
      expect(response.body).to include('value="milk"')
    end

    it "merges fragment-scoped params after a preceding full-container update" do
      session = Rack::Test::Session.new(Rack::MockSession.new(search_app.generate))
      html = session.get("/").body

      full = session.post(field_path(html, "query"), "query" => "oat", "query_inside" => "")
      expect(full.body).to include("outside:oat")

      scoped = session.post(field_path(full.body, "query_inside"), "query" => "oat", "query_inside" => "milk")

      expect(scoped.body).to include("inside:milk")
      expect(scoped.body).not_to include("outside:")
    end

    it "merges params posted with a deferred fragment's auto-fetch" do
      app = StreamWeaver::App.new("Deferred merge") do
        text_field :query
        fragment(:stats, defer: true) { text "stats:#{state[:query]}" }
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body

      response = session.post(deferred_path(html, "sw-frag-stats"), "query" => "milk")

      expect(response.body).to include("stats:milk")
    end
  end
end
