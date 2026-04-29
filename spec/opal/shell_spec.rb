# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/shell"

RSpec.describe StreamWeaver::Opal::OpalShell do
  describe ".render" do
    let(:html) { described_class.render(title: "My App", app_js: "app.js") }

    it "includes DOCTYPE" do
      expect(html).to start_with("<!DOCTYPE html>")
    end

    it "includes the title" do
      expect(html).to include("<title>My App</title>")
    end

    it "loads morphdom from CDN" do
      expect(html).to include("morphdom")
    end

    it "includes the sw-app mount point" do
      expect(html).to include('id="sw-app"')
    end

    it "loads app.js" do
      expect(html).to include('src="app.js"')
    end

    it "calls SWRuntime.start() after scripts load" do
      expect(html).to include("SWRuntime.start()")
    end
  end
end
