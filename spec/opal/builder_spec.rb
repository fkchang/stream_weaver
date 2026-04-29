# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/opal/shell"
require "stream_weaver/opal/builder"
require "tmpdir"

RSpec.describe StreamWeaver::Opal::OpalBuilder do
  describe ".build" do
    let(:app_content) do
      <<~RUBY
        require 'stream_weaver/opal_entry'
        app "Test" do
          text "hello"
        end
      RUBY
    end

    around do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    it "creates the output directory" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(Dir.exist?(out)).to be true
    end

    it "writes index.html" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(File.exist?(File.join(out, "index.html"))).to be true
    end

    it "writes app.js" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      expect(File.exist?(File.join(out, "app.js"))).to be true
    end

    it "includes Opal runtime in app.js" do
      app_file = File.join(@tmpdir, "app.rb")
      File.write(app_file, app_content)
      out = File.join(@tmpdir, "dist")
      described_class.build(app_file, output_dir: out)
      js = File.read(File.join(out, "app.js"))
      expect(js).to include("Opal")  # Opal runtime marker
    end
  end
end
