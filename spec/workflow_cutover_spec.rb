# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Tyrion workflow cutover" do
  let(:repo_root) { File.expand_path("..", __dir__) }

  def repo_file(path)
    File.read(File.join(repo_root, path))
  end

  it "makes Tyrion authoritative and Beads legacy-only in tracked guidance" do
    guidance = [repo_file("AGENTS.md"), repo_file("CLAUDE.md")].join("\n")

    expect(guidance).to include("Tyrion is authoritative")
    expect(guidance).to include("legacy backlog")
    expect(guidance).not_to include("Use `bd` for ALL task tracking")
    expect(guidance).not_to include("bv --robot-triage")
  end

  it "keeps the Git hook tracker-neutral and preserves the hygiene gate" do
    hook = repo_file(".githooks/pre-commit")

    expect(hook).to include("bin/check_git_hygiene")
    expect(hook).not_to match(/\bbd\b|beads hooks/)
  end

  it "configures the neutral hook path and Tyrion's Claude hooks from bin/setup" do
    setup = repo_file("bin/setup")

    expect(setup).to include("git config core.hooksPath .githooks")
    expect(setup).to include("tyrion init")
    expect(setup).to include("tyrion setup claude")
    expect(setup).not_to include("bd prime")
  end
end
