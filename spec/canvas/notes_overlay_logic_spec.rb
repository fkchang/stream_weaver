# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'

# The overlay's pure helpers, run in node without a DOM: the composer title
# names the highlighted element, and the inline comment editor's keys.
RSpec.describe 'sw-canvas-notes.js helpers' do
  let(:src) { File.read(File.join(__dir__, '../../lib/stream_weaver/assets/js/sw-canvas-notes.js')) }

  def run_node(expr)
    fns = src.scan(/^  function (?:titleFor|editKeyAction|activeAfter|badgeVisible|innermost|dropHover|badgeShown|newIds|openFor)\(.*?^  \}|^  function titleFor\(el\) \{.*?\}$/m).join("\n")
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

  it 'keeps ONE active comment: only another comment, Esc with no editor, a page click, Send or removal change it' do
    expect(run_node(<<~JS)).to eq(['2', '2', nil, nil, nil, '1', nil, '1', '3'])
      (() => {
        const a = activeAfter;
        return [
          a('1', {type: 'activate', id: '2'}),                      // another comment wins
          a('2', {type: 'escape', editing: true}),                  // Esc inside the editor keeps it
          a('2', {type: 'escape', editing: false}),                 // Esc with no editor clears it
          a('2', {type: 'pageClick'}),                              // empty page click clears it
          a('2', {type: 'send'}),                                   // Send clears it
          a('1', {type: 'remove', id: '2'}),                        // removing another leaves it
          a('2', {type: 'remove', id: '2'}),                        // removing the active clears it
          a('1', {type: 'editEnd'}),                                // Save or Cancel leaves it active
          a('3', {type: 'present', ids: ['1', '3']})                // still present after a region swap
        ];
      })()
    JS
    expect(run_node("activeAfter('9', {type: 'present', ids: ['1']})")).to be_nil
  end

  it 'shows a badge only when its anchor is clear of the right panel, the bottom sheet and the viewport' do
    expect(run_node(<<~JS)).to eq([true, false, false, false, false])
      (() => {
        const desktop = {right: 928, bottom: 800}, mobile = {right: 390, bottom: 500};
        return [
          badgeVisible(100, 100, desktop),
          badgeVisible(920, 100, desktop),   // under the 320px panel
          badgeVisible(50, 495, mobile),     // under the bottom sheet
          badgeVisible(50, -20, desktop),    // scrolled above the viewport
          badgeVisible(-30, 100, desktop)
        ];
      })()
    JS
  end

  it 'picks the innermost commented element when several contain the click' do
    # li holds strong; table holds li. contains(a, b): a's box holds b.
    nest = "const holds = {table: ['li', 'strong'], li: ['strong'], strong: []}; const c = (a, b) => holds[a].includes(b);"
    expect(run_node("(() => { #{nest} return [innermost(['table', 'li', 'strong'], c), innermost(['li', 'table'], c), innermost(['li'], c), innermost([], c)]; })()"))
      .to eq(['strong', 'li', 'li', nil])
  end

  it 'activating strips the hover preview classes from the selected element' do
    js = <<~JS
      (() => {
        const set = new Set(['sw-hl', 'sw-hl-card', 'sw-hl-sel']);
        const el = {classList: {remove: (c) => set.delete(c)}};
        dropHover(el);
        return [...set];
      })()
    JS
    expect(run_node(js)).to eq(['sw-hl-sel'])
  end

  it 'CSS: the selected and composer outlines beat both hover previews in any pairing' do
    css = src[/css\.textContent =(.*?);\n\s*document\.head/m, 1].scan(/'((?:[^'\\]|\\.)*)'/).flatten.join
    rules = css.scan(/([^{}]+)\{([^}]*)\}/).map { |sel, body| [sel.split(','), body] }
    winner = lambda do |classes|
      best = nil
      rules.each_with_index do |(sels, body), idx|
        next unless body.include?('outline:') && !body.include?('outline:none')

        sels.each do |sel|
          needed = sel.strip.scan(/\.([\w-]+)/).flatten
          next if needed.empty? || sel.strip =~ /[\s>]/ || !(needed - classes).empty?

          key = [needed.size, idx]
          best = [key, body] if best.nil? || (key <=> best[0]) == 1
        end
      end
      best && best[1]
    end
    [%w[sw-hl-card sw-hl-sel], %w[sw-hl sw-hl-sel], %w[sw-hl-card sw-hl-comp], %w[sw-hl sw-hl-comp]].each do |pair|
      expect(winner.call(pair)).to include('solid'), "#{pair.join(' + ')} resolves to #{winner.call(pair).inspect}"
    end
    expect(winner.call(%w[sw-hl-card])).to include('dashed')
  end

  it 'badge rule: live comments always show, Done ones only with Done and their round open or when selected' do
    expect(run_node(<<~JS)).to eq([true, true, false, false, false, true, true])
      (() => [
        badgeShown('queued', false, false, false),
        badgeShown('working', false, false, false),
        badgeShown('done', false, false, false),
        badgeShown('done', true, false, false),   // Done open, round closed
        badgeShown('done', false, true, false),   // round open, Done closed
        badgeShown('done', true, true, false),
        badgeShown('done', false, false, true)    // selected Done comment keeps its badge
      ])()
    JS
  end

  it 'state restore: saved open keys reopen, everything else is closed; new ids are found' do
    expect(run_node("[openFor({done: true, r2: true}, 'done'), openFor({done: true}, 'r2'), openFor(null, 'done'), openFor({}, 'r1')]"))
      .to eq([true, false, false, false])
    expect(run_node("[newIds(['1','2'], ['1','2','3']), newIds(['1','2'], ['2']), newIds([], ['4','5'])]"))
      .to eq([['3'], [], %w[4 5]])
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
