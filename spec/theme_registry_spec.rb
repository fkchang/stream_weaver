# frozen_string_literal: true

# The built-in themes are one list: each registers through register_theme
# with its label and fonts, and App's list is derived from the registry.
# Their CSS stays in AppView.master_theme_css.
RSpec.describe 'built-in theme registry' do
  let(:built_ins) { %i[default dashboard document dark doc ide] }

  it 'derives App::BUILT_IN_THEMES from the registry' do
    expect(StreamWeaver.built_in_themes).to eq(built_ins)
    expect(StreamWeaver::App::BUILT_IN_THEMES).to eq(built_ins)
  end

  it 'keeps no second list of built-ins on Theme' do
    expect(StreamWeaver::Theme.const_defined?(:BUILT_IN_THEMES, false)).to be false
  end

  it 'registers :dark, so the theme switcher offers it' do
    expect(StreamWeaver.theme_exists?(:dark)).to be true
    entry = StreamWeaver.all_themes_for_switcher.find { |t| t[:id] == :dark }
    expect(entry).to include(label: 'Dark')
  end

  it 'lists the built-ins first in the switcher, in registry order' do
    ids = StreamWeaver.all_themes_for_switcher.map { |t| t[:id] }
    expect(ids.first(built_ins.size)).to eq(built_ins)
  end

  it 'carries no variables metadata for the hand-tuned built-ins (their CSS is in master_theme_css)' do
    built_ins.each { |name| expect(StreamWeaver.get_theme(name).variables).to eq({}), name.to_s }
  end

  it 'keeps the fonts and stylesheets a built-in declares' do
    expect(StreamWeaver.theme_fonts(:ide)).to eq(['JetBrains+Mono:wght@400;500;600;700'])
    expect(StreamWeaver.theme_stylesheets(:ide)).to eq(['https://cdn.jsdelivr.net/npm/@fontsource-variable/geist@5.2.8/index.css'])
    expect(StreamWeaver.theme_fonts(:dark)).to eq([])
  end

  it 'reads fonts and stylesheets a custom theme declares, and does not count it as built-in' do
    StreamWeaver.register_theme(:registry_spec_custom, { color_primary: '#123456' },
                                fonts: ['Inter:wght@400'], stylesheets: ['https://example.test/x.css'])
    expect(StreamWeaver.theme_fonts(:registry_spec_custom)).to eq(['Inter:wght@400'])
    expect(StreamWeaver.theme_stylesheets(:registry_spec_custom)).to eq(['https://example.test/x.css'])
    expect(StreamWeaver.built_in_themes).not_to include(:registry_spec_custom)
  ensure
    StreamWeaver.themes.delete(:registry_spec_custom)
  end

  it 'drops Outfit, which nothing loads, from the :dark font stack' do
    dark = StreamWeaver::Views::AppView.master_theme_css[/body\.sw-theme-dark \{.*?\n\s*\}/m]
    expect(dark).not_to include('Outfit')
    expect(dark).to include("--sw-font-body: 'Source Sans 3', system-ui, sans-serif;")
  end
end
