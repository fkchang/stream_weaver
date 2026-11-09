# frozen_string_literal: true

require 'rack/test'
require 'tmpdir'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'theme token CSS (page-assets token-css-generator)' do
  let(:dark_selectors) { 'html.dark body.sw-theme-x, html[data-sw-theme="dark"] body.sw-theme-x' }

  describe 'Theme.token_css' do
    it 'emits the scope with the light tokens, then both dark signals with the dark tokens' do
      css = StreamWeaver::Theme.token_css('body.sw-theme-x', { color_primary: '#111' }, dark: { color_bg: '#000' })

      expect(css).to eq(<<~CSS)
        body.sw-theme-x {
          --sw-color-primary: #111;
        }
        #{dark_selectors} {
          --sw-color-bg: #000;
        }
      CSS
    end

    it 'leaves the dark block out when there are no dark tokens' do
      css = StreamWeaver::Theme.token_css('body.sw-theme-x', { color_primary: '#111' })

      expect(css).to eq("body.sw-theme-x {\n  --sw-color-primary: #111;\n}\n")
    end

    it 'puts both dark signals on <html> itself for the :root scope' do
      css = StreamWeaver::Theme.token_css(':root', { '--sw-bg' => '#fff' }, dark: { '--sw-bg' => '#000' })

      expect(css).to include(":root {\n  --sw-bg: #fff;\n}")
      expect(css).to include("html.dark, html[data-sw-theme=\"dark\"] {\n  --sw-bg: #000;\n}")
    end

    it 'names a token by its schema entry, a raw custom property as given, anything else as --sw-<name>' do
      css = StreamWeaver::Theme.token_css('body', { vs_bg: '1', '--x-y' => '2', made_up: '3', sw_raw: '4' })

      expect(css).to include('--sw-bg: 1;', '--x-y: 2;', '--sw-made-up: 3;', '--sw-raw: 4;')
    end
  end

  describe 'Theme::SURFACE_TOKENS (owner decision 2)' do
    it 'is exactly the set of tokens the framework dark block (html.dark body) gives its own value' do
      css = StreamWeaver::Views::AppView.master_theme_css
      dark_block = css[/^\s*html\.dark body \{(.*?)\}/m, 1]
      declared = dark_block.scan(/(--sw-[a-z0-9-]+):/).flatten
      surface = StreamWeaver::Theme::SURFACE_TOKENS.map { |key| StreamWeaver::Theme::VARIABLE_SCHEMA.fetch(key)[:css] }

      expect(surface).to match_array(declared)
    end

    it 'carries every light token but the surface ones into dark mode, and dark: wins' do
      light = { color_primary: '#a21caf', color_bg: '#fdf4ff', shadow_md: 'none' }

      expect(StreamWeaver::Theme.dark_tokens(light, {})).to eq(color_primary: '#a21caf')
      expect(StreamWeaver::Theme.dark_tokens(light, { color_bg: '#120712', color_primary: '#f0abfc' }))
        .to eq(color_primary: '#f0abfc', color_bg: '#120712')
    end
  end

  describe 'Presets.generate_preset_css' do
    it 'uses the generator, so a preset goes dark on either dark signal' do
      css = StreamWeaver::Theme::Presets.generate_preset_css(:editorial)

      expect(css).to include(":root {\n  --sw-")
      expect(css).to include("html.dark, html[data-sw-theme=\"dark\"] {\n")
    end
  end

  describe 'register_theme' do
    after { StreamWeaver.themes.delete(:tokens_spec_harbor) }

    it 'generates light and dark CSS from a hash, plus the css: it is given, with no hand-written token CSS' do
      theme = StreamWeaver.register_theme(:tokens_spec_harbor,
                                          { color_primary: '#0e7490', color_bg: '#f7fafa' },
                                          dark: { color_primary: '#22d3ee', color_bg: '#0b1416' },
                                          css: 'body.sw-theme-tokens_spec_harbor h2 { letter-spacing: -0.01em; }',
                                          label: 'Harbor')

      expect(theme.label).to eq('Harbor')
      expect(theme.to_css).to eq(<<~CSS)
        body.sw-theme-tokens_spec_harbor {
          --sw-color-primary: #0e7490;
          --sw-color-bg: #f7fafa;
        }
        html.dark body.sw-theme-tokens_spec_harbor, html[data-sw-theme="dark"] body.sw-theme-tokens_spec_harbor {
          --sw-color-primary: #22d3ee;
          --sw-color-bg: #0b1416;
        }
        body.sw-theme-tokens_spec_harbor h2 { letter-spacing: -0.01em; }
      CSS
    end

    it "wears its base theme's class first, so the page gets the base theme's type, spacing and radius" do
      StreamWeaver.register_theme(:tokens_spec_harbor, { color_primary: '#0e7490' })
      page = StreamWeaver::PageShell.resolve(nil, theme: :tokens_spec_harbor, layout: nil)

      expect(StreamWeaver.get_theme(:tokens_spec_harbor).base_theme).to eq(:default)
      expect(page.body_class).to eq('sw-theme-default sw-theme-tokens_spec_harbor')
    end

    it 'wears a named base theme' do
      StreamWeaver.register_theme(:tokens_spec_harbor, {}, base: :dashboard)

      expect(StreamWeaver::PageShell.resolve(nil, theme: :tokens_spec_harbor, layout: nil).body_class)
        .to eq('sw-theme-dashboard sw-theme-tokens_spec_harbor')
    end

    it 'reaches an Opal build, whose stylesheet carries the theme CSS' do
      require 'stream_weaver/opal/builder'
      theme = StreamWeaver.register_theme(:tokens_spec_harbor, { color_primary: '#0e7490' })
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'app.rb'), "app 'x' do\nend\n")
        builder = StreamWeaver::Opal::OpalBuilder.new(File.join(dir, 'app.rb'), output_dir: dir,
                                                                                 theme: :tokens_spec_harbor)
        builder.send(:write_theme_css)

        expect(File.read(File.join(dir, 'sw-theme.css'))).to include(theme.to_css)
      end
    end

    it 'keeps a surface token light-only when no dark: is given' do
      theme = StreamWeaver.register_theme(:tokens_spec_harbor, { color_primary: '#0e7490', color_bg: '#f7fafa' })
      dark_block = theme.to_css.split("html.dark").last

      expect(dark_block).to include('--sw-color-primary: #0e7490;')
      expect(dark_block).not_to include('--sw-color-bg')
    end
  end

  describe 'App#theme_tokens and theme_overrides:' do
    let(:scope) { StreamWeaver::Theme::TOKEN_SCOPE }

    it 'generates one layered-ready block per distinct call, scoped to whichever theme the body wears' do
      app = StreamWeaver::App.new('T')
      2.times { app.theme_tokens(color_primary: '#a21caf', dark: { color_bg: '#120712' }) }

      expect(app.theme_token_css).to eq([StreamWeaver::Theme.token_css(
        scope, { color_primary: '#a21caf' }, dark: { color_bg: '#120712' }, carry: true
      )])
      expect(scope).to eq('body[class*="sw-theme-"]')
    end

    it 'routes theme_overrides: through the same generator' do
      app = StreamWeaver::App.new('T', theme_overrides: { color_primary: '#a21caf', color_bg: '#fdf4ff' })

      expect(app.theme_token_css).to eq([StreamWeaver::Theme.token_css(
        scope, { color_primary: '#a21caf', color_bg: '#fdf4ff' }, dark: { color_primary: '#a21caf' }
      )])
    end

    it 'warns once for a token no built-in styling reads, however often it is declared' do
      expect do
        app = StreamWeaver::App.new('T', theme_overrides: { not_a_real_token: 'nope' })
        app.theme_tokens(not_a_real_token: 'other')
        app.rebuild_with_state({})
      end.to output(/\A[^\n]*Unknown theme token[^\n]*not_a_real_token[^\n]*\n\z/).to_stderr
    end

    it 'does not warn for a raw custom property, which token_css names as given' do
      expect { StreamWeaver::App.new('T').theme_tokens('--x-y': '1') }.not_to output.to_stderr
    end

    it 'starts each render from theme_overrides: alone, so state-dependent tokens do not pile up' do
      app = StreamWeaver::App.new('T', theme_overrides: { color_primary: '#111' }) do
        theme_tokens color_accent: state[:accent]
      end
      app.rebuild_with_state({ accent: '#222' })
      app.rebuild_with_state({ accent: '#333' })

      expect(app.theme_token_css.join).to include('#111', '#333')
      expect(app.theme_token_css.join).not_to include('#222')
    end

    # [ids, classes/attributes/pseudo-classes, elements]: checks the cascade, not only strings.
    def specificity(selector)
      bare = selector.gsub(/\[[^\]]*\]/, '[]')
      [bare.scan(/#[\w-]+/).size, bare.scan(/\.[\w-]+|\[\]|:[\w-]+/).size, bare.scan(/(?:^|\s)[a-z]+/).size]
    end

    it 'ties a theme block in light mode and follows it, and outranks every built-in dark block' do
      light, dark = StreamWeaver::Theme.token_css(scope, { color_primary: '#1' }, carry: true).scan(/^(.+) \{$/).flatten
      builtin_dark = ['html.dark body', 'html[data-sw-theme="dark"] body.sw-theme-doc', 'html.dark body.sw-theme-ide']

      expect(specificity(light)).to eq(specificity('body.sw-theme-default'))
      dark.split(', ').product(builtin_dark).each do |ours, theirs|
        expect(specificity(ours) <=> specificity(theirs)).to be >= 0 # a tie goes to ours, emitted later
      end
      expect(specificity(dark.split(', ').first) <=> specificity('html.dark body')).to eq(1)
      app = StreamWeaver::App.new('T', theme_overrides: { color_primary: '#1' })
      html = StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
      expect(html.index("#{light} {")).to be > html.index('body.sw-theme-default {')
    end
  end

  describe 'theme_tokens on every host' do
    let(:dsl) do
      <<~RUBY
        theme_tokens color_primary: '#a21caf', dark: { color_bg: '#120712' }
        text "tokens probe"
      RUBY
    end
    let(:block) do
      StreamWeaver::Theme.token_css(
        StreamWeaver::Theme::TOKEN_SCOPE, { color_primary: '#a21caf' }, dark: { color_bg: '#120712' }, carry: true
      )
    end

    def rack_get(app, path)
      Rack::MockRequest.new(app).get(path, 'HTTP_HOST' => 'localhost').body
    end

    def expect_after_master(html)
      expect(html).to include(block)
      expect(html.index(block)).to be > html.index('html.dark body {')
    end

    it 'standalone: in the framework layer, after the built-in theme CSS' do
      source = dsl
      app = StreamWeaver::App.new('T') { instance_eval(source) }
      app.rebuild_with_state({})
      html = StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call

      expect_after_master(html)
      expect(html).to include(StreamWeaver::CSS.layer_wrap(block))
    end

    it 'export' do
      expect_after_master(StreamWeaver::Export::HtmlExporter.from_dsl(dsl).to_html)
    end

    it 'a canvas push' do
      server = StreamWeaver::Canvas::BridgeServer
      previous = server.bridge
      server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      server.bridge.create_session('tokens', theme: :doc)
      server.bridge.handle_claude_message(type: 'push', name: 'tokens', dsl: dsl)

      expect_after_master(rack_get(server, '/canvas/tokens'))
    ensure
      server.bridge = previous
    end

    it 'the reader' do
      reader = StreamWeaver::Canvas::Reader
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'tokens.rb'), dsl)
        previous = reader.file_list
        reader.configure_files!(reader::FileList.build([dir]))
        expect_after_master(rack_get(reader, '/?file=0'))
      ensure
        reader.configure_files!(previous)
      end
    end
  end

  it 'says once, in an Opal runtime, that theme_tokens is not rendered there' do
    require 'stream_weaver/opal/env'
    require 'stream_weaver/opal/renderer'
    require 'stream_weaver/adapter/opal'
    require 'stream_weaver/opal/runtime'
    runtime = StreamWeaver::Opal::OpalRuntime.new(adapter: StreamWeaver::Adapter::Opal.new)
    runtime.set_block { theme_tokens color_primary: '#a21caf' }

    expect { 2.times { runtime.render_html } }
      .to output(/\A[^\n]*theme_tokens is not rendered in an Opal build[^\n]*\n\z/).to_stderr
  end

  it 'gives the :doc dark block both dark signals' do
    css = StreamWeaver::Views::AppView.master_theme_css

    expect(css).to match(/html\.dark body\.sw-theme-doc,\s*html\[data-sw-theme="dark"\] body\.sw-theme-doc \{\s*--sw-color-primary: #6699FF;/)
  end
end
