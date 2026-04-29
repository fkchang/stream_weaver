# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rack/test'
require 'stream_weaver/canvas/reader'

RSpec.describe StreamWeaver::Canvas::Reader::FileList, 'with history_roots' do
  around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

  before do
    @docs_dir = File.join(@dir, 'docs')
    @history_root = File.join(@dir, 'history')
    @session_a = File.join(@history_root, 'brainstorm')
    @session_b = File.join(@history_root, 'auth-flow')
    [@docs_dir, @session_a, @session_b].each { |d| FileUtils.mkdir_p(d) }

    File.write(File.join(@docs_dir, 'arch.rb'),       "header1 'Arch'")
    File.write(File.join(@docs_dir, 'auth-final.rb'), "header1 'Auth Final'")
    File.write(File.join(@session_a, '20260427_120000.rb'), "header1 'Brainstorm v1'")
    File.write(File.join(@session_a, '20260427_130000.rb'), "header1 'Brainstorm v2'")
    File.write(File.join(@session_b, '20260427_140000.rb'), "header1 'Auth-flow draft'")
  end

  let(:file_list) do
    described_class.build([@docs_dir, @session_a, @session_b], history_roots: [@history_root])
  end

  it 'tags files under the history_roots as history' do
    expect(file_list.history_dir?(@session_a)).to be true
    expect(file_list.history_dir?(@session_b)).to be true
    expect(file_list.history_dir?(@docs_dir)).to be false
  end

  it 'docs_groups excludes history sessions' do
    expect(file_list.docs_groups.keys).to contain_exactly(@docs_dir)
  end

  it 'history_groups includes only sessions under history_roots' do
    expect(file_list.history_groups.keys).to contain_exactly(@session_a, @session_b)
  end

  it 'preserves the global file index across both group types' do
    docs_indices = file_list.docs_groups.values.flatten(1).map(&:last)
    history_indices = file_list.history_groups.values.flatten(1).map(&:last)
    all_indices = (docs_indices + history_indices).sort
    expect(all_indices).to eq((0...file_list.size).to_a)
  end

  it 'defaults history_roots to empty (backward compat)' do
    list = described_class.build([@docs_dir])
    expect(list.docs_groups.keys).to contain_exactly(@docs_dir)
    expect(list.history_groups).to be_empty
  end
end

RSpec.describe StreamWeaver::Canvas::Reader, 'sidebar with history section' do
  include Rack::Test::Methods
  def app = described_class

  around { |ex| Dir.mktmpdir { |d| @dir = d; ex.run } }

  before do
    @docs_dir = File.join(@dir, 'docs')
    @history_root = File.join(@dir, 'history')
    @session = File.join(@history_root, 'brainstorm')
    [@docs_dir, @session].each { |d| FileUtils.mkdir_p(d) }

    File.write(File.join(@docs_dir, 'arch.rb'), "header1 'Arch'")
    File.write(File.join(@session, '20260427_120000.rb'), "header1 'B1'")
    File.write(File.join(@session, '20260427_130000.rb'), "header1 'B2'")

    list = StreamWeaver::Canvas::Reader::FileList.build(
      [@docs_dir, @session],
      history_roots: [@history_root]
    )
    described_class.configure_files!(list)
  end

  let(:html) do
    get '/?file=0'
    last_response.body
  end

  it 'renders both Docs and History sidebar sections' do
    expect(html).to match(/Docs/)
    expect(html).to match(/History/)
  end

  it 'history section starts collapsed' do
    # The section markup should explicitly mark itself as collapsed at render time
    expect(html).to match(/history.*collapsed|collapsed.*history/i)
  end

  it 'history entries link by file index (same routing as docs)' do
    # session entries should be reachable via the same /?file=N route
    expect(html).to include('/?file=1')  # one of the history files
    expect(html).to include('/?file=2')
  end

  it 'docs section has no collapsed marker (default expanded)' do
    # Find the docs section's dir-files element and assert it is not collapsed.
    docs_section_match = html.match(/<h2[^>]*>Docs<\/h2>(.+?)(<h2|<\/nav>)/m)
    expect(docs_section_match).not_to be_nil
    docs_block = docs_section_match[1]
    expect(docs_block).not_to match(/dir-files\s+collapsed/)
  end

  it 'shows a session count in the History header' do
    expect(html).to match(/History.*\(1\b/)
  end

  it 'history entries display the timestamp as label' do
    expect(html).to include('20260427_120000')
    expect(html).to include('20260427_130000')
  end
end
