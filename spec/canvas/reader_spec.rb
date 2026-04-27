# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stream_weaver/canvas/reader'

RSpec.describe StreamWeaver::Canvas::Reader::FileList do
  around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

  def touch(rel)
    path = File.join(@dir, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "header1 '#{rel}'")
    path
  end

  describe '.build' do
    it 'accepts explicit file paths' do
      f = touch('a.rb')
      list = described_class.build([f])
      expect(list.files).to eq([f])
    end

    it 'scans a directory for *.rb files' do
      touch('x.rb')
      touch('y.rb')
      list = described_class.build([@dir])
      expect(list.files.size).to eq(2)
    end

    it 'ignores non-.rb files in directory scan' do
      touch('a.rb')
      File.write(File.join(@dir, 'readme.md'), 'ignore me')
      list = described_class.build([@dir])
      expect(list.files.size).to eq(1)
    end

    it 'raises if no files resolve' do
      expect { described_class.build(['/nonexistent/path.rb']) }
        .to raise_error(StreamWeaver::Canvas::Reader::NoFilesError)
    end

    it 'combines explicit files and directory scan' do
      f1 = touch('sub/extra.rb')
      touch('a.rb')
      list = described_class.build([@dir, f1])
      expect(list.files).to include(f1)
    end
  end

  describe '#groups' do
    it 'groups files by parent directory' do
      d2 = File.join(@dir, 'sub')
      FileUtils.mkdir_p(d2)
      f1 = touch('a.rb')
      f2 = touch('sub/b.rb')
      list = described_class.build([f1, f2])
      groups = list.groups
      expect(groups.keys).to include(@dir, d2)
    end
  end

  describe '#at' do
    it 'returns file at index' do
      f = touch('a.rb')
      list = described_class.build([f])
      expect(list.at(0)).to eq(f)
    end

    it 'returns nil for out-of-range index' do
      f = touch('a.rb')
      list = described_class.build([f])
      expect(list.at(99)).to be_nil
    end
  end
end
