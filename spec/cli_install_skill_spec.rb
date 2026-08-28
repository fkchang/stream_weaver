# frozen_string_literal: true
require "spec_helper"
require "stream_weaver/cli"
require "tmpdir"

# Registration coverage for the canvas-safe skill added to CLI.install_skill's
# gem_skills table (lib/stream_weaver/cli.rb). No prior spec covered this
# table at all, so this pins the whole set rather than adding a fourth
# untested entry next to three already-untested ones.
#
# stream_weaver-5fyf: install_skill used to symlink only each skill's
# SKILL.md file, leaving sibling examples/ and references/ subdirectories
# unreachable through the installed path (only discoverable by having the
# source repo checked out separately). Fixed by symlinking the whole skill
# directory instead -- these specs pin THAT shape, not the old file-only one.
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

    it "symlinks every gem-sourced skill's whole directory into .claude/skills, not just SKILL.md" do
      %w[streamweaver-visual-companion streamweaver-doc-builder streamweaver-way streamweaver-canvas-safe visual-plan visual-recap].each do |name|
        dir_link = File.join(Dir.pwd, ".claude", "skills", name)

        expect(File.symlink?(dir_link)).to be(true), "#{dir_link} was not created as a symlink"
        expect(File.readlink(dir_link)).to end_with(File.join("skills", name))
        expect(File.exist?(File.join(dir_link, "SKILL.md"))).to be(true)
      end
    end

    it "also symlinks canvas-safe's directory into the cross-tool .agents/skills alias" do
      dir_link = File.join(Dir.pwd, ".agents", "skills", "streamweaver-canvas-safe")

      expect(File.symlink?(dir_link)).to be(true)
    end

    it "also symlinks visual-plan and visual-recap into the cross-tool .agents/skills alias" do
      %w[visual-plan visual-recap].each do |name|
        dir_link = File.join(Dir.pwd, ".agents", "skills", name)

        expect(File.symlink?(dir_link)).to be(true), "#{dir_link} was not created as a symlink"
        expect(File.readlink(dir_link)).to end_with(File.join("skills", name))
      end
    end

    it "points canvas-safe at a real SKILL.md with the expected frontmatter name" do
      link = File.join(Dir.pwd, ".claude", "skills", "streamweaver-canvas-safe", "SKILL.md")

      expect(File.read(link)).to match(/^name:\s*streamweaver-canvas-safe$/)
    end

    it "makes a skill's examples/ and references/ subdirectories reachable through the installed path" do
      # visual-companion has both -- exactly the progressive-disclosure
      # content that was silently unreachable outside the source repo
      # before this fix (stream_weaver-5fyf).
      base = File.join(Dir.pwd, ".claude", "skills", "streamweaver-visual-companion")

      expect(File.exist?(File.join(base, "examples", "doc-parity-example.rb"))).to be(true)
      expect(File.exist?(File.join(base, "references", "checkpoints-and-forms.md"))).to be(true)
    end

    it "re-running install_skill (upgrade/reinstall) does not fail on an already-installed skill" do
      expect { described_class.install_skill([]) }.not_to raise_error

      link = File.join(Dir.pwd, ".claude", "skills", "streamweaver-visual-companion")
      expect(File.symlink?(link)).to be(true)
    end
  end
end
