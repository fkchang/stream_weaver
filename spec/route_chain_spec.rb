# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "Route chain foundation (T1)" do
  describe "App#route_rules" do
    it "initializes @route_rules as empty array" do
      app = StreamWeaver::App.new("Test") {}
      expect(app.route_rules).to eq([])
    end

    it "initializes @resource_defs as empty hash" do
      app = StreamWeaver::App.new("Test") {}
      expect(app.resource_defs).to eq({})
    end
  end

  describe "App#route_with" do
    it "appends a RouteRule to @route_rules" do
      app = StreamWeaver::App.new("Test") {}
      parser  = ->(p) { p == '/hello' ? { page: :hello } : nil }
      builder = ->(s) { s[:page] == :hello ? '/hello' : nil }

      app.route_with(parser: parser, builder: builder)

      expect(app.route_rules.length).to eq(1)
      expect(app.route_rules.first).to be_a(StreamWeaver::RouteRule)
      expect(app.route_rules.first.parser).to eq(parser)
      expect(app.route_rules.first.builder).to eq(builder)
    end

    it "two route_with calls contribute two rules" do
      app = StreamWeaver::App.new("Test") {}
      parser1 = ->(p) { p == '/alpha' ? { page: :alpha } : nil }
      parser2 = ->(p) { p == '/beta'  ? { page: :beta  } : nil }

      app.route_with(parser: parser1)
      app.route_with(parser: parser2)

      expect(app.route_rules.length).to eq(2)
    end

    it "is idempotent — same parser lambda registers only once" do
      app = StreamWeaver::App.new("Test") {}
      parser = ->(p) { p == '/foo' ? { page: :foo } : nil }

      app.route_with(parser: parser)
      app.route_with(parser: parser)
      app.route_with(parser: parser)

      expect(app.route_rules.length).to eq(1)
    end
  end

  describe "route_by backward compatibility" do
    it "still sets @route_key and @routes" do
      app = StreamWeaver::App.new("Test") {}
      app.route_by :page, home: '/', about: '/about'

      expect(app.route_key).to eq(:page)
      expect(app.routes).to eq(home: '/', about: '/about')
    end

    it "state_for_path resolves via route_by" do
      app = StreamWeaver::App.new("Test") {}
      app.route_by :page, home: '/', about: '/about'

      expect(app.state_for_path('/')).to eq({ page: :home })
      expect(app.state_for_path('/about')).to eq({ page: :about })
    end

    it "path_for_state resolves via route_by" do
      app = StreamWeaver::App.new("Test") {}
      app.route_by :page, home: '/', about: '/about'

      expect(app.path_for_state({ page: :home })).to eq('/')
      expect(app.path_for_state({ page: :about })).to eq('/about')
    end
  end

  describe "rules persist across rebuild_with_state" do
    it "does not clear @route_rules on rebuild" do
      app = StreamWeaver::App.new("Test") {}
      parser = ->(p) { p == '/x' ? { page: :x } : nil }
      app.route_with(parser: parser)

      3.times { app.rebuild_with_state({}) }

      expect(app.route_rules.length).to eq(1)
    end

    it "does not clear @resource_defs on rebuild" do
      app = StreamWeaver::App.new("Test") {}
      # Manually populate resource_defs to verify persistence
      app.instance_variable_get(:@resource_defs)[:foo] = :bar

      3.times { app.rebuild_with_state({}) }

      expect(app.resource_defs[:foo]).to eq(:bar)
    end

    it "rules still resolve paths after multiple rebuilds" do
      app = StreamWeaver::App.new("Test") {}
      parser = ->(p) { p == '/persist' ? { page: :persist } : nil }
      app.route_with(parser: parser)

      3.times { app.rebuild_with_state({}) }

      expect(app.state_for_path('/persist')).to eq({ page: :persist })
    end
  end

  describe "App#routable?" do
    it "returns false on a fresh app with no routing configured" do
      app = StreamWeaver::App.new("Test") {}
      expect(app.routable?).to be_falsey
    end

    it "returns true after route_by is called" do
      app = StreamWeaver::App.new("Test") {}
      app.route_by :page, home: '/'
      expect(app.routable?).to be_truthy
    end

    it "returns true after route_with is called" do
      app = StreamWeaver::App.new("Test") {}
      app.route_with(parser: ->(p) { nil })
      expect(app.routable?).to be_truthy
    end
  end

  describe "App#state_for_path iterates @route_rules chain" do
    it "returns match from first matching rule" do
      app = StreamWeaver::App.new("Test") {}
      parser1 = ->(p) { p == '/one' ? { hit: :rule1 } : nil }
      parser2 = ->(p) { p == '/two' ? { hit: :rule2 } : nil }
      app.route_with(parser: parser1)
      app.route_with(parser: parser2)

      expect(app.state_for_path('/one')).to eq({ hit: :rule1 })
      expect(app.state_for_path('/two')).to eq({ hit: :rule2 })
    end

    it "returns nil when no rule matches and no route_by" do
      app = StreamWeaver::App.new("Test") {}
      app.route_with(parser: ->(p) { nil })

      expect(app.state_for_path('/nope')).to be_nil
    end

    it "falls back to route_by when route_rules don't match" do
      app = StreamWeaver::App.new("Test") {}
      app.route_by :page, home: '/'
      app.route_with(parser: ->(p) { p == '/dynamic' ? { page: :dynamic } : nil })

      expect(app.state_for_path('/')).to eq({ page: :home })
      expect(app.state_for_path('/dynamic')).to eq({ page: :dynamic })
    end
  end
end
