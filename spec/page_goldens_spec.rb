# frozen_string_literal: true

require_relative 'support/page_goldens'

# The golden gate for the page-assets epic: every later change to how a page
# is assembled (themes, fonts, stylesheets, scripts, body classes) is checked
# against these files, and only a diff a story states is allowed.
#
# What is recorded, per built-in theme and host (standalone AppView, canvas,
# reader, export, Opal), in spec/fixtures/page_goldens/<host>/<theme>.txt:
# the <body> class, the ordered <head> one tag per line, and the <style>
# blocks the body carries. Every CSS block lives once in css_blocks.css and
# is referenced by a 12-character digest of its content.
#
# Normalisations, each because the raw value is noise rather than signal:
# - <style> bodies become "[css <digest>]"; the CSS itself is in css_blocks.css.
# - inline <script> bodies become "[script <digest>, N bytes]": scripts are
#   not CSS, and a changed script still shows up as a changed digest.
# - whitespace between tags is collapsed to one tag per line, because Phlex
#   renders a single line and the heredoc hosts render indented ones.
# - the Opal build pins mermaid to a local stub (see PageGoldens.render_opal).
# Nothing else is rewritten: the probe uses fixed names, so no port,
# timestamp or generated id reaches the head or the CSS.
#
# An intended diff: run `UPDATE_GOLDENS=1 bundle exec rspec spec/page_goldens_spec.rb`,
# review `git diff spec/fixtures/page_goldens`, and name the diff in the commit.
RSpec.describe 'page goldens (page-assets gate)' do
  before(:all) do
    PageGoldens.reset!
    @fresh = PageGoldens.render_all
    if ENV['UPDATE_GOLDENS'] == '1'
      FileUtils.rm_rf(PageGoldens::ROOT)
      @fresh.each do |path, content|
        full = File.join(PageGoldens::ROOT, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, content)
      end
    end
  end

  def golden(path)
    full = File.join(PageGoldens::ROOT, path)
    return File.read(full) if File.exist?(full)

    raise "missing golden #{path}: run UPDATE_GOLDENS=1 bundle exec rspec #{__FILE__}"
  end

  it 'lists every host it cannot render without a browser, with the reason' do
    expect(PageGoldens::EXCLUSIONS.keys).to contain_exactly('opal app.js', 'opal runtime theme', 'extension head')
    PageGoldens::EXCLUSIONS.each { |part, why| expect(why).not_to be_empty, "#{part} has no reason" }
  end

  it 'records every theme on every host, and nothing else' do
    on_disk = Dir.glob('**/*', base: PageGoldens::ROOT).select { |p| File.file?(File.join(PageGoldens::ROOT, p)) }
    expect(on_disk).to match_array(@fresh.keys)
  end

  PageGoldens::HOSTS.product(PageGoldens::THEMES).each do |host, theme|
    it "#{host} / :#{theme} matches its golden" do
      expect(@fresh.fetch("#{host}/#{theme}.txt")).to eq(golden("#{host}/#{theme}.txt"))
    end
  end

  it 'extension base_stylesheet matches its golden' do
    expect(@fresh.fetch('extension/base_stylesheet.txt')).to eq(golden('extension/base_stylesheet.txt'))
  end

  it 'every CSS block matches css_blocks.css' do
    expect(@fresh.fetch('css_blocks.css')).to eq(golden('css_blocks.css'))
  end

  it 'renders the same output twice (nothing nondeterministic leaks in)' do
    PageGoldens.reset!
    expect(PageGoldens.render_all).to eq(@fresh)
  end
end
