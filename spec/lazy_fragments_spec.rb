# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "cgi"

# `fragment(:name, defer: true, lazy: true)` is Turbo's `loading="lazy"`. What
# the server owes is the trigger and the wrapper; whether an IntersectionObserver
# actually stays silent for a hidden element is a browser claim, verified in the
# browser pass. Trigger rationale:
# docs/research/2026-08-22-lazy-fragments-trigger-decision.md.
RSpec.describe "lazy fragments" do
  let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

  def render(app, state = {})
    app.rebuild_with_state(state, generation: "lazy-session")
    StreamWeaver::Views::AppContentView.new(app, state, adapter, false).call
  end

  # The auto-fetch wrapper for one fragment, whatever its trigger.
  def wrapper_for(html, fragment_id)
    html.scan(/<div[^>]+hx-target="##{Regexp.escape(fragment_id)}"[^>]*>/)
        .find { |w| w.include?("hx-trigger=") } or raise "no fetch wrapper for ##{fragment_id} in #{html}"
  end

  def fetch_path(html, fragment_id)
    CGI.unescapeHTML(wrapper_for(html, fragment_id)[/hx-post="([^"]+)"/, 1])
  end

  # The first block button on the page -- posting it is a full-container swap.
  def action_path(html)
    CGI.unescapeHTML(html[%r{hx-post="(/action/[^"]+)"}, 1])
  end

  describe "the visibility trigger" do
    # `once` is not decoration: htmx's IntersectionObserver keeps observing after
    # it fires, so without it every scroll back into the viewport would refetch.
    # The latch is stored per element in htmx's internal data, so it survives
    # re-visibility but not element replacement -- which is what keeps the
    # full-container re-arm below working.
    it "waits for intersection instead of firing on load" do
      app = StreamWeaver::App.new("Lazy") do
        fragment(:card, defer: true, lazy: true) { text "REAL CARD" }
      end

      html = render(app)

      expect(wrapper_for(html, "sw-frag-card")).to include('hx-trigger="intersect once"')
      expect(html).not_to include('hx-trigger="load"')
    end

    it "leaves a plain deferred fragment firing on load" do
      app = StreamWeaver::App.new("Eager defer") { fragment(:card, defer: true) { text "REAL CARD" } }

      expect(wrapper_for(render(app), "sw-frag-card")).to include('hx-trigger="load"')
    end

    # The class is how the browser-verification runbook counts un-materialized
    # lazy fragments (`document.querySelectorAll('.sw-fragment-lazy').length`),
    # which is the check that a hidden fragment never fetched.
    it "marks the wrapper with a lazy class" do
      app = StreamWeaver::App.new("Class") { fragment(:card, lazy: true) { text "REAL CARD" } }

      expect(wrapper_for(render(app), "sw-frag-card")).to include("sw-fragment-lazy")
    end
  end

  describe "shell render" do
    it "renders the placeholder without executing the lazy block" do
      executed = false
      app = StreamWeaver::App.new("Shell") do
        text "FAST SHELL"
        fragment(:card, defer: true, lazy: true, placeholder: "Loading card…") do
          executed = true
          text "REAL CARD"
        end
      end

      html = render(app)

      expect(executed).to be(false)
      expect(html).to include("FAST SHELL", "Loading card…", 'id="sw-frag-card"')
      expect(html).not_to include("REAL CARD")
    end
  end

  # Turbo's `loading="lazy"` is meaningless without `src`; the StreamWeaver
  # equivalent is that lazy implies defer. Requiring the author to write both
  # would be friction with no decision behind it -- the DSL already implies
  # options elsewhere (area_chart is line_chart with fill:).
  describe "lazy implies defer" do
    it "defers the block without an explicit defer:" do
      executed = false
      app = StreamWeaver::App.new("Implied") do
        fragment(:card, lazy: true) do
          executed = true
          text "REAL CARD"
        end
      end

      html = render(app)

      expect(executed).to be(false)
      expect(html).not_to include("REAL CARD")
      expect(wrapper_for(html, "sw-frag-card")).to include('hx-trigger="intersect once"')
    end

    it "accepts a placeholder without an explicit defer:" do
      app = StreamWeaver::App.new("Implied placeholder") do
        fragment(:card, lazy: true, placeholder: "Loading…") { text "REAL CARD" }
      end

      expect(render(app)).to include("Loading…")
    end

    it "still rejects a placeholder on a fragment that is neither deferred nor lazy" do
      expect {
        StreamWeaver::App.new("Oops") { fragment(:card, placeholder: "Loading…") { text "body" } }
          .rebuild_with_state({})
      }.to raise_error(ArgumentError, /placeholder: requires defer: true/)
    end
  end

  describe "the fetch itself" do
    it "returns just that fragment's content through the signed endpoint" do
      app = StreamWeaver::App.new("Fetch") do
        fragment(:card, lazy: true, placeholder: "Loading…") { text "REAL CARD" }
        text "UNRELATED PAGE COPY"
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body

      response = session.post(fetch_path(html, "sw-frag-card"))

      expect(response.status).to eq(200)
      expect(response.body).to include("REAL CARD")
      expect(response.body).not_to include("UNRELATED PAGE COPY", "Loading…")
    end
  end

  # A full-container swap re-renders the lazy fragment as a brand-new wrapper
  # element. htmx's `once` latch is per element, so the fresh wrapper re-arms --
  # but on `intersect`, so it still waits for visibility rather than firing
  # immediately the way a plain deferred fragment does.
  describe "composition with the full-container re-arm" do
    it "re-arms as a lazy wrapper after a full-container update" do
      app = StreamWeaver::App.new("Re-arm") do
        fragment(:card, lazy: true, placeholder: "Loading…") { text "REAL CARD" }
        button("Re-render") { |s| s[:renders] = s[:renders].to_i + 1 }
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      html = session.get("/").body
      expect(html).to include("Loading…")

      session.post(fetch_path(html, "sw-frag-card"))
      rerendered = session.post(action_path(html)).body

      expect(rerendered).to include("Loading…")
      expect(rerendered).not_to include("REAL CARD")
      expect(wrapper_for(rerendered, "sw-frag-card")).to include('hx-trigger="intersect once"')
    end
  end

  # The infinite-scroll shape from the Turbo Frames course: each page's content
  # ends with the next page's lazy placeholder, so pages materialize one at a
  # time as the reader scrolls, with no pagination JavaScript.
  describe "nested lazy fragments (Russian dolls / infinite scroll)" do
    # Apps write this as a plain method (see examples/lazy_fragments_demo.rb);
    # a self-referential lambda is the same shape without defining a method on
    # Object for the whole suite.
    def paged_app
      StreamWeaver::App.new("Infinite") do
        page = nil
        page = lambda do |number|
          fragment(:"page_#{number}", lazy: true, placeholder: "Loading page #{number}…") do
            text "PAGE #{number} BODY"
            page.call(number + 1) if number < 3
          end
        end
        page.call(1)
      end
    end

    it "ships only the first sentinel and reveals one page per fetch" do
      session = Rack::Test::Session.new(Rack::MockSession.new(paged_app.generate))
      shell = session.get("/").body

      expect(shell).to include("Loading page 1…")
      expect(shell).not_to include("PAGE 1 BODY", "PAGE 2 BODY")

      page1 = session.post(fetch_path(shell, "sw-frag-page-1")).body
      expect(page1).to include("PAGE 1 BODY", "Loading page 2…")
      expect(page1).not_to include("PAGE 2 BODY")

      page2 = session.post(fetch_path(page1, "sw-frag-page-1--page-2")).body
      expect(page2).to include("PAGE 2 BODY", "Loading page 3…")
      expect(page2).not_to include("PAGE 3 BODY")
    end

    it "keeps every nested sentinel on the intersect trigger" do
      session = Rack::Test::Session.new(Rack::MockSession.new(paged_app.generate))
      shell = session.get("/").body
      page1 = session.post(fetch_path(shell, "sw-frag-page-1")).body

      expect(wrapper_for(page1, "sw-frag-page-1--page-2")).to include('hx-trigger="intersect once"')
      expect(page1).not_to include('hx-trigger="load"')
    end

    it "chains a lazy fragment nested inside a plain deferred one" do
      app = StreamWeaver::App.new("Mixed nesting") do
        fragment(:outer, defer: true) do
          text "OUTER BODY"
          fragment(:inner, lazy: true) { text "INNER BODY" }
        end
      end
      session = Rack::Test::Session.new(Rack::MockSession.new(app.generate))
      shell = session.get("/").body

      expect(wrapper_for(shell, "sw-frag-outer")).to include('hx-trigger="load"')

      outer = session.post(fetch_path(shell, "sw-frag-outer")).body
      expect(outer).to include("OUTER BODY")
      expect(outer).not_to include("INNER BODY")
      expect(wrapper_for(outer, "sw-frag-outer--inner")).to include('hx-trigger="intersect once"')

      inner = session.post(fetch_path(outer, "sw-frag-outer--inner")).body
      expect(inner).to include("INNER BODY")
    end
  end

  # The recipe llms.txt sells as "a tab panel that loads when you open it", and
  # the shape docs/research/2026-08-22-lazy-fragments-trigger-decision.md
  # specifies for lazy route tabs. Route tabs render EVERY panel and hide the
  # inactive ones with x-show/x-cloak, so the server's half of the recipe is
  # checkable: the inactive panel's fragment must ship un-materialized on the
  # intersect trigger. Selecting the tab is a client-side display flip, which is
  # what the browser pass verifies.
  describe "inside a route-tab panel" do
    def tabbed_app
      StreamWeaver::App.new("Tabbed") do
        tabs :view, url: true do
          tab("Summary") { text "SUMMARY BODY" }
          tab("Revenue") do
            fragment(:revenue, lazy: true, placeholder: "Loading revenue…") { text "REVENUE BODY" }
          end
        end
      end
    end

    it "ships the inactive panel's fragment un-materialized on the intersect trigger" do
      html = render(tabbed_app)

      expect(html).to include("SUMMARY BODY", "Loading revenue…", 'x-show="activeTab === 1"')
      expect(html).not_to include("REVENUE BODY")
      expect(wrapper_for(html, "sw-frag-revenue")).to include('hx-trigger="intersect once"')
    end

    # The fragment lives inside the `tab` block, so it is a child of the Tab
    # rather than of the tabs group -- which is what keeps it out of the
    # all-children panel counting disc-085 describes.
    it "leaves the panel indices alone" do
      html = render(tabbed_app)

      expect(html.scan(/x-show="activeTab === \d+"/)).to eq(['x-show="activeTab === 0"',
                                                             'x-show="activeTab === 1"'])
    end

    it "materializes only that fragment when its panel is opened" do
      session = Rack::Test::Session.new(Rack::MockSession.new(tabbed_app.generate))
      html = session.get("/").body

      response = session.post(fetch_path(html, "sw-frag-revenue"))

      expect(response.body).to include("REVENUE BODY")
      expect(response.body).not_to include("SUMMARY BODY", "sw-tabs-list")
    end
  end

  describe "static export" do
    it "runs lazy blocks inline, since nothing will ever scroll an exported file" do
      app = StreamWeaver::App.new("Exported") do
        text "SHELL"
        fragment(:card, lazy: true, placeholder: "Loading…") { text "REAL CARD" }
      end

      html = StreamWeaver::Export::HtmlExporter.new(app).to_html

      expect(html).to include("SHELL", "REAL CARD")
      expect(html).not_to include("Loading…", "hx-trigger")
    end
  end
end
