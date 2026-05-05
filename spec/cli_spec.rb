# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/cli"
require "stream_weaver/opal/builder"
require "tmpdir"

RSpec.describe StreamWeaver::CLI do
  describe ".opal_build" do
    let(:app_content) do
      <<~RUBY
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

    let(:app_file) { File.join(@tmpdir, "app.rb") }
    let(:output_dir) { File.join(@tmpdir, "dist") }

    before do
      File.write(app_file, app_content)
    end

    context "with --theme editorial" do
      it "passes theme: 'editorial' to OpalBuilder.build" do
        expect(StreamWeaver::Opal::OpalBuilder).to receive(:build)
          .with(app_file, output_dir: output_dir, theme: "editorial")

        described_class.opal_build([app_file, "--output", output_dir, "--theme", "editorial"])
      end
    end

    context "without --theme" do
      it "passes theme: nil to OpalBuilder.build" do
        expect(StreamWeaver::Opal::OpalBuilder).to receive(:build)
          .with(app_file, output_dir: output_dir, theme: nil)

        described_class.opal_build([app_file, "--output", output_dir])
      end
    end

    context "with --theme in different position" do
      it "still extracts the theme value" do
        expect(StreamWeaver::Opal::OpalBuilder).to receive(:build)
          .with(app_file, output_dir: output_dir, theme: "editorial")

        # --theme before --output
        described_class.opal_build([app_file, "--theme", "editorial", "--output", output_dir])
      end
    end
  end
end
