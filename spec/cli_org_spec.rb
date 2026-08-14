# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "stream_weaver/cli"
require_relative "../lib/stream_weaver/org/writer"

RSpec.describe StreamWeaver::CLI do
  around do |ex|
    Dir.mktmpdir do |dir|
      @dir = dir
      Dir.chdir(dir) { ex.run }
    end
  end

  let(:sample_dsl) { eval(File.read(File.join(__dir__, "fixtures/org/sample_doc.rb"))) } # rubocop:disable Security/Eval

  describe ".org_export" do
    it "writes a sibling .org file next to the given .rb file" do
      rb_path = File.join(@dir, "sample.rb")
      File.write(rb_path, sample_dsl)

      expect { described_class.org_export([rb_path]) }.to output(/Wrote/).to_stdout

      org_path = File.join(@dir, "sample.org")
      expect(File.exist?(org_path)).to be true
      expect(File.read(org_path)).to start_with("#+STREAMWEAVER_DSL: 1")
    end

    it "warns to stderr before overwriting an existing .org file" do
      rb_path = File.join(@dir, "sample.rb")
      File.write(rb_path, sample_dsl)
      org_path = File.join(@dir, "sample.org")
      File.write(org_path, "stale content")

      expect { described_class.org_export([rb_path]) }
        .to output(/Warning: overwriting existing #{Regexp.escape(org_path)}/).to_stderr
    end

    it "reports a clean error and exits 1 on invalid DSL, instead of a raw backtrace" do
      rb_path = File.join(@dir, "bad.rb")
      File.write(rb_path, "this is not valid ruby {{{")

      expect { described_class.org_export([rb_path]) }
        .to raise_error(SystemExit)
        .and output(/Error: org-export failed:/).to_stderr
    end

    it "exits with usage when given a directory instead of a file" do
      expect { described_class.org_export([@dir]) }
        .to raise_error(SystemExit)
        .and output(/Usage: streamweaver org-export/).to_stderr
    end
  end

  describe ".org_render" do
    it "prints DSL text to stdout for a given .org file" do
      org_path = File.join(@dir, "sample.org")
      File.write(org_path, StreamWeaver::Org::Writer.from_dsl(sample_dsl))

      expect { described_class.org_render([org_path]) }.to output(/doc_section_header/).to_stdout
    end

    it "reports a clean error and exits 1 on malformed org input, instead of a raw backtrace" do
      org_path = File.join(@dir, "bad.org")
      File.write(org_path, "#+begin_src ruby\nno end")

      expect { described_class.org_render([org_path]) }
        .to raise_error(SystemExit)
        .and output(/Error: org-render failed:/).to_stderr
    end

    it "exits with usage when given a directory instead of a file" do
      expect { described_class.org_render([@dir]) }
        .to raise_error(SystemExit)
        .and output(/Usage: streamweaver org-render/).to_stderr
    end
  end
end
