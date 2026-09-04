# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/cli"

# `streamweaver install` is the friendlier public name for `streamweaver
# setup` (Forrest's 3-step pitch: gem install stream_weaver; streamweaver
# install; streamweaver get-started). Both names must dispatch to the same
# CLI.setup, and the alias must be discoverable in --help.
RSpec.describe StreamWeaver::CLI do
  describe "the 'install' command" do
    it "dispatches to .setup, same as 'setup'" do
      expect(described_class).to receive(:setup)

      described_class.run(["install"])
    end

    it "'setup' still works" do
      expect(described_class).to receive(:setup)

      described_class.run(["setup"])
    end
  end

  describe ".help" do
    it "documents the install command" do
      expect { described_class.help }.to output(/streamweaver install\b/).to_stdout
    end
  end
end
