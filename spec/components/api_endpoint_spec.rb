# frozen_string_literal: true

RSpec.describe "ApiEndpoint Component" do
  describe StreamWeaver::Components::ApiEndpoint do
    it "upcases the http method" do
      ep = described_class.new(method: "post", path: "/users")
      expect(ep.http_method).to eq("POST")
    end

    it "stores path" do
      ep = described_class.new(method: "GET", path: "/users")
      expect(ep.path).to eq("/users")
    end

    it "defaults description to nil" do
      ep = described_class.new(method: "GET", path: "/users")
      expect(ep.description).to be_nil
    end

    it "accepts description" do
      ep = described_class.new(method: "GET", path: "/users", description: "List all users")
      expect(ep.description).to eq("List all users")
    end

    it "defaults params to empty array" do
      ep = described_class.new(method: "GET", path: "/users")
      expect(ep.params).to eq([])
    end

    it "accepts params array" do
      params = [{ name: "email", type: "string", required: true }]
      ep = described_class.new(method: "POST", path: "/users", params: params)
      expect(ep.params).to eq(params)
    end

    it "defaults response to empty hash" do
      ep = described_class.new(method: "GET", path: "/users")
      expect(ep.response).to eq({})
    end

    it "accepts response hash" do
      ep = described_class.new(method: "GET", path: "/users", response: { id: "integer" })
      expect(ep.response).to eq({ id: "integer" })
    end

    describe "#badge_color" do
      it "returns green for POST" do
        ep = described_class.new(method: "POST", path: "/")
        expect(ep.badge_color).to eq("#16a34a")
      end

      it "returns blue for GET" do
        ep = described_class.new(method: "GET", path: "/")
        expect(ep.badge_color).to eq("#2563eb")
      end

      it "returns red for DELETE" do
        ep = described_class.new(method: "DELETE", path: "/")
        expect(ep.badge_color).to eq("#dc2626")
      end

      it "returns amber for PUT" do
        ep = described_class.new(method: "PUT", path: "/")
        expect(ep.badge_color).to eq("#d97706")
      end

      it "returns amber for PATCH" do
        ep = described_class.new(method: "PATCH", path: "/")
        expect(ep.badge_color).to eq("#d97706")
      end

      it "returns gray for unknown methods" do
        ep = described_class.new(method: "CUSTOM", path: "/")
        expect(ep.badge_color).to eq("#6b7280")
      end
    end
  end

  describe "HTML rendering" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }
    let(:state)   { {} }

    def render_html(component)
      StreamWeaver::ComponentRenderer.render_html(adapter, [component], state)
    end

    def make_endpoint(method: "POST", path: "/users", description: nil, params: [], response: {})
      StreamWeaver::Components::ApiEndpoint.new(
        method: method, path: path, description: description,
        params: params, response: response
      )
    end

    it "renders without error" do
      expect { render_html(make_endpoint) }.not_to raise_error
    end

    it "renders the outer sw-api-endpoint container" do
      html = render_html(make_endpoint)
      expect(html).to include("sw-api-endpoint")
    end

    it "renders the HTTP method badge" do
      html = render_html(make_endpoint(method: "POST"))
      expect(html).to include("POST")
      expect(html).to include("sw-api-endpoint__method")
    end

    it "renders the path in monospace span" do
      html = render_html(make_endpoint(path: "/api/v1/users"))
      expect(html).to include("/api/v1/users")
      expect(html).to include("sw-api-endpoint__path")
    end

    it "applies green badge color for POST" do
      html = render_html(make_endpoint(method: "POST"))
      expect(html).to include("#16a34a")
    end

    it "applies blue badge color for GET" do
      html = render_html(make_endpoint(method: "GET"))
      expect(html).to include("#2563eb")
    end

    it "applies red badge color for DELETE" do
      html = render_html(make_endpoint(method: "DELETE"))
      expect(html).to include("#dc2626")
    end

    it "renders description when provided" do
      html = render_html(make_endpoint(description: "Creates a new user account"))
      expect(html).to include("Creates a new user account")
      expect(html).to include("sw-api-endpoint__description")
    end

    it "omits description section when nil" do
      html = render_html(make_endpoint(description: nil))
      expect(html).not_to include('class="sw-api-endpoint__description"')
    end

    it "renders params table with Name/Type/Required headers" do
      params = [{ name: "email", type: "string", required: true }]
      html = render_html(make_endpoint(params: params))
      expect(html).to include("sw-api-endpoint__table")
      expect(html).to include("Name")
      expect(html).to include("Type")
      expect(html).to include("Required")
    end

    it "renders param name, type, and required status" do
      params = [{ name: "email", type: "string", required: true }]
      html = render_html(make_endpoint(params: params))
      expect(html).to include("email")
      expect(html).to include("string")
      expect(html).to include("yes")
    end

    it "renders 'no' for non-required params" do
      params = [{ name: "page", type: "integer", required: false }]
      html = render_html(make_endpoint(params: params))
      expect(html).to include("no")
    end

    it "omits params section when empty" do
      html = render_html(make_endpoint(params: []))
      expect(html).not_to include('class="sw-api-endpoint__table"')
    end

    it "renders response section when provided" do
      html = render_html(make_endpoint(response: { id: "integer", email: "string" }))
      expect(html).to include("sw-api-endpoint__response")
      expect(html).to include("id")
      expect(html).to include("integer")
    end

    it "omits response section when empty" do
      html = render_html(make_endpoint(response: {}))
      expect(html).not_to include('class="sw-api-endpoint__response"')
    end

    it "injects CSS once for multiple components" do
      ep1 = make_endpoint(method: "GET", path: "/a")
      ep2 = make_endpoint(method: "POST", path: "/b")
      html = StreamWeaver::ComponentRenderer.render_html(adapter, [ep1, ep2], state)
      expect(html.scan("sw-api-endpoint__method").length).to be >= 2
      expect(html.scan("-- ApiEndpoint --").length).to eq(1)
    end
  end

  describe "Adapter::Base#render_api_endpoint" do
    it "raises NotImplementedError" do
      adapter = StreamWeaver::Adapter::Base.new
      expect {
        adapter.render_api_endpoint(nil, nil, nil)
      }.to raise_error(NotImplementedError, /render_api_endpoint/)
    end
  end

  describe "DisplayDSL#api_endpoint" do
    it "is available as a DSL method" do
      app = StreamWeaver::App.new("Test") do
        api_endpoint(method: "GET", path: "/users")
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ApiEndpoint) }
      expect(component).not_to be_nil
      expect(component.http_method).to eq("GET")
      expect(component.path).to eq("/users")
    end

    it "passes params through the DSL" do
      app = StreamWeaver::App.new("Test") do
        api_endpoint(
          method: "POST",
          path: "/users",
          params: [{ name: "email", type: "string", required: true }]
        )
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ApiEndpoint) }
      expect(component.params.length).to eq(1)
      expect(component.params.first[:name]).to eq("email")
    end

    it "passes response through the DSL" do
      app = StreamWeaver::App.new("Test") do
        api_endpoint(method: "GET", path: "/users", response: { id: "integer" })
      end
      app.rebuild_with_state({})
      component = app.components.find { |c| c.is_a?(StreamWeaver::Components::ApiEndpoint) }
      expect(component.response).to eq({ id: "integer" })
    end
  end

  describe "sw- CSS prefix convention" do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new }

    it "all CSS class selectors use sw- prefix" do
      css = adapter.send(:api_endpoint_css)
      selector_lines = css.lines.select { |l| l.include?("{") && !l.strip.start_with?("/*") }
      class_selectors = selector_lines.flat_map { |l|
        selector_part = l.split("{").first || ""
        selector_part.scan(/(?<![a-zA-Z])\.([\w][\w-]*)/).flatten
      }.uniq

      expect(class_selectors).not_to be_empty
      class_selectors.each do |cls|
        expect(cls).to start_with("sw-"),
          "CSS class '.#{cls}' does not use sw- prefix"
      end
    end
  end
end
