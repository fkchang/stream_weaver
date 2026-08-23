# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/cli"
require "tmpdir"

# Registration coverage for the canvas-safe skill added to CLI.install_skill's
# gem_skills table (lib/stream_weaver/cli.rb). No prior spec covered this
# table at all, so this pins the whole set rather than adding a fourth
# untested entry next to three already-untested ones.
RSpec.describe StreamWeaver::CLI do
  describe ".install_skill" do
    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) { example.run }
      end
    end

    # Project-local (no --global) so this never touches the real
    # ~/.claude/skills or ~/.agents/skills on the machine running the suite.
    before { described_class.install_skill([]) }

    it "symlinks every gem-sourced skill's SKILL.md into .claude/skills" do
      %w[streamweaver-visual-companion streamweaver-doc-builder streamweaver-way streamweaver-canvas-safe].each do |name|
        link = File.join(Dir.pwd, ".claude", "skills", name, "SKILL.md")

        expect(File.symlink?(link)).to be(true), "#{link} was not created as a symlink"
        expect(File.readlink(link)).to end_with(File.join("skills", name, "SKILL.md"))
      end
    end

    it "also symlinks canvas-safe into the cross-tool .agents/skills alias" do
      link = File.join(Dir.pwd, ".agents", "skills", "streamweaver-canvas-safe", "SKILL.md")

      expect(File.symlink?(link)).to be(true)
    end

    it "points canvas-safe at a real SKILL.md with the expected frontmatter name" do
      link = File.join(Dir.pwd, ".claude", "skills", "streamweaver-canvas-safe", "SKILL.md")

      expect(File.read(link)).to match(/^name:\s*streamweaver-canvas-safe$/)
    end
  end
end
