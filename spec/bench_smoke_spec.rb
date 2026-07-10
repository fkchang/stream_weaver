# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe "benchmark harness" do
  it "boots every fixture and completes a one-iteration run" do
    command = [Gem.ruby, File.expand_path("../bench/run.rb", __dir__), "--iterations", "1", "--warmups", "0", "--no-write"]
    output, status = Open3.capture2e(*command)
    output.force_encoding(Encoding::UTF_8)
    expect(status).to be_success, output
    expect(output).to include("# Phase-1 dispatch benchmark")
    expect(output).to match(/\*\*(?:PASS|FAIL)\*\*/)
  end
end
