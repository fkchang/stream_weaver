# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/university/scripts/growing_doc_state'

RSpec.describe StreamWeaver::University::Scripts::GrowingDocState do
  around do |example|
    Dir.mktmpdir('growing_doc_state') do |dir|
      prev = ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR']
      ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = dir
      @dir = dir
      example.run
    ensure
      ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] = prev
    end
  end

  describe '.path' do
    it 'derives a per-session filename from the session name' do
      expect(described_class.path('doc-demo')).to eq(File.join(@dir, 'doc-demo_state.yml'))
    end

    it 'keeps different sessions in different files' do
      expect(described_class.path('doc-demo')).not_to eq(described_class.path('other-doc'))
    end
  end

  describe '.load' do
    it 'is empty when nothing has ever been saved' do
      expect(described_class.load('doc-demo')).to eq([])
    end

    it 'returns nothing (not an error) for a syntactically invalid state file' do
      FileUtils.mkdir_p(@dir)
      File.write(described_class.path('doc-demo'), "not: valid: yaml: [")

      expect(described_class.load('doc-demo')).to eq([])
    end

    it 'returns nothing (not an error) for a file whose YAML root is not a hash' do
      FileUtils.mkdir_p(@dir)
      File.write(described_class.path('doc-demo'), "- tradeoffs\n- cheatsheet\n")

      expect(described_class.load('doc-demo')).to eq([])
    end
  end

  describe '.save / .load round trip' do
    it 'round-trips exactly what was saved' do
      described_class.save('doc-demo', %w[tradeoffs cheatsheet])

      expect(described_class.load('doc-demo')).to eq(%w[tradeoffs cheatsheet])
    end

    it 'overwrites rather than accumulates on a second save' do
      described_class.save('doc-demo', %w[tradeoffs])
      described_class.save('doc-demo', %w[tradeoffs cheatsheet])

      expect(described_class.load('doc-demo')).to eq(%w[tradeoffs cheatsheet])
    end
  end

  describe '.clear' do
    it 'removes a saved state so .load goes back to empty' do
      described_class.save('doc-demo', %w[tradeoffs])

      described_class.clear('doc-demo')

      expect(described_class.load('doc-demo')).to eq([])
    end

    it 'is a no-op, not an error, when nothing was ever saved' do
      expect { described_class.clear('doc-demo') }.not_to raise_error
    end
  end
end
