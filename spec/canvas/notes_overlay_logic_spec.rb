# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'

# The overlay's pure helpers, run in node without a DOM: the composer title
# names the highlighted element, and the inline comment editor's keys.
RSpec.describe 'sw-canvas-notes.js helpers' do
  let(:src) { File.read(File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-canvas-notes.js')) }

  def run_node(expr)
    fns = src.scan(/^  function (?:titleFor|editKeyAction)\(.*?^  \}|^  function titleFor\(el\) \{.*?\}$/m).join("\n")
    out, err, st = Open3.capture3('node', '-e', "#{fns}\nconsole.log(JSON.stringify(#{expr}))")
    raise "node failed: #{err}" unless st.success?

    JSON.parse(out)
  end

  it 'titles the composer with the tag of the element itself' do
    expect(run_node("['TD','P','BUTTON'].map(t => titleFor({tagName: t}))")).to eq(['Annotate <td>', 'Annotate <p>', 'Annotate <button>'])
  end

  it 'maps editor keys: Enter saves non-empty text, Esc cancels' do
    expect(run_node("[editKeyAction('Enter','x'), editKeyAction('Enter','  '), editKeyAction('Escape','x'), editKeyAction('a','x')]"))
      .to eq(['save', nil, 'cancel', nil])
  end

  it 'has no browser dialog and puts the inline input in the pill' do
    expect(src).not_to include('prompt(')
    expect(src).to include('sw-notes-input')
  end

  it 'keeps the framework button spinner off the panel and the save-doc button clear of it' do
    expect(src).to include('aside[data-sw-region] button::after{content:none')
    expect(src).to include('.sw-save-doc-btn{right:calc(320px').and include('bottom:calc(40vh + 1rem)')
  end
end
