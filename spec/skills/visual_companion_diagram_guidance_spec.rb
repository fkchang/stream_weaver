# frozen_string_literal: true

require 'spec_helper'
require 'slim_graph_r'
require 'stream_weaver'
require 'stream_weaver/cli'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'
require 'tmpdir'

RSpec.describe 'Visual Companion SlimGraphR diagram guidance' do
  let(:skill_dir) { File.expand_path('../../lib/stream_weaver/skills/streamweaver-visual-companion', __dir__) }
  let(:skill) { File.read(File.join(skill_dir, 'SKILL.md'), encoding: Encoding::UTF_8) }
  let(:guide_path) { File.join(skill_dir, 'references/slim-graph-r-diagrams.md') }
  let(:guide) { File.read(guide_path, encoding: Encoding::UTF_8) }

  it 'keeps the atlas on demand while directing diagram work to the guide' do
    expect(skill).to include('`diagram` is a first-class StreamWeaver DSL method')
    expect(skill).to include('`streamweaver diagrams`')
    expect(skill).to include('references/slim-graph-r-diagrams.md')
    expect(guide).to include('all 39 examples')
  end

  it 'gives a complete bare-DSL document scaffold that crosses saved, canvas, and export boundaries' do
    scaffold = guide.split('## Complete document scaffold', 2).last
                    .split('Pick the picture', 2).first
                    .scan(/```ruby\n(.*?)\n```/m).flatten.fetch(0)

    expect(scaffold).to include('# streamweaver-doc: v1')
    expect(scaffold).to include("require 'stream_weaver'")
    expect(scaffold).to include('diagram :architecture')
    expect(scaffold).not_to include('document do')

    canvas = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, scaffold, session_name: 'guide-scaffold')
    reader = StreamWeaver::Canvas::Reader.render_doc(scaffold)
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(scaffold).to_html

    expect(canvas.error).to be_nil
    expect([canvas.html, reader.html, exported]).to all(include('<svg'))
  end

  it 'accounts for every supported SlimGraphR type in its six-family index' do
    index = guide.split('## Full type index', 2).last
    documented_types = index.scan(/`:(\w+)`/).flatten.map(&:to_sym)

    expect(documented_types).to contain_exactly(*SlimGraphR::Diagram::TYPES)
    expect(documented_types.length).to eq(39)
    expect(index.scan(/^\- \*\*/).length).to eq(6)
  end

  it 'keeps each family pattern executable as written' do
    patterns = guide.split('## Minimal runnable patterns', 2).last
                    .split('## Full type index', 2).first
                    .scan(/```ruby\n(.*?)\n```/m).flatten

    expect(patterns.length).to eq(6)
    patterns.each do |source|
      app = StreamWeaver::App.new('Guide pattern')
      app.instance_eval(source)
      html = StreamWeaver::ComponentRenderer.render_html(StreamWeaver::Adapter::AlpineJS.new, app.components)

      expect(html).to include('<svg')
    end
  end

  it 'installs the referenced guide with the skill directory' do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        StreamWeaver::CLI.install_skill([])

        installed_guide = File.join(dir, '.claude', 'skills', 'streamweaver-visual-companion',
                                     'references', 'slim-graph-r-diagrams.md')
        expect(File.exist?(installed_guide)).to be(true)
        expect(File.read(installed_guide, encoding: Encoding::UTF_8)).to include('## Minimal runnable patterns')
      end
    end
  end
end
