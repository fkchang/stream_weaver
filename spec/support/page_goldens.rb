# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'rack/test'
require 'tmpdir'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'
require 'stream_weaver/opal/builder'

# Renders one fixed probe page for every built-in theme on every host and
# reduces each render to what the page-assets epic must not change by
# accident: the ordered <head>, the <body> class, and every CSS block in
# document order. spec/page_goldens_spec.rb compares the result with the
# files under spec/fixtures/page_goldens; UPDATE_GOLDENS=1 rewrites them.
module PageGoldens
  # Every built-in theme, in registration order (theme/built_ins.rb), so a new
  # built-in is gated without editing this file.
  THEMES = StreamWeaver.built_in_themes.freeze
  HOSTS  = %i[standalone canvas reader export opal live].freeze
  # Hosts whose body is filled in the browser, so the probe's text is not in the HTML.
  BROWSER_FILLED = %i[opal live].freeze

  # Hosts, or parts of a host, that cannot be rendered without a browser or
  # a full compile. Listed here (and printed by the spec) so nothing is
  # silently skipped.
  EXCLUSIONS = {
    'opal app.js' => 'compiling app.js needs the opal compiler and takes seconds per theme; ' \
                     'the head, body class and sw-theme.css are produced by the builder steps ' \
                     'that run without it (write_theme_css, write_index_html), so those are recorded',
    'opal runtime theme' => 'none of the six built-in themes is a Theme::Presets entry, so the Opal CSS is ' \
                            'the same for every theme; only the body class and the theme font and ' \
                            'stylesheet links vary; a theme the app applies at runtime happens in the browser. ' \
                            'One preset\'s CSS is recorded on its own (presets/editorial.txt)',
    'live body content' => 'the /live page fills #app-container in the browser by polling; its head, ' \
                           'body class and body asset tags are recorded',
    'extension head' => 'the extension page is assembled in the browser by sandbox.js; only its ' \
                        'framework CSS input, CSS.base_stylesheet (bin/build_extension), is recorded'
  }.freeze

  PROBE_DSL = <<~RUBY
    header1 "Page probe"
    button "Go"
    table [{ "name" => "alpha", "value" => 1 }]
    callout "Heads up", variant: :info
    ide_shell do
      ide_titlebar { text "probe" }
      ide_editor { text "editor" }
      ide_statusbar { text "status" }
    end
  RUBY

  # A second probe, rendered for :default only, for the paths the main probe
  # never reaches: app fonts:, an app stylesheets: URL, a use_stylesheet
  # block, a layout slot and chrome: false. A DSL fragment host (canvas,
  # reader) can carry only the DSL parts; the exporter and standalone get a
  # real App. Plus one standalone htmx partial (AppContentView).
  VARIANT_THEME = :default
  VARIANT_HOSTS = %i[standalone standalone_partial canvas reader export opal].freeze
  VARIANT_APP_OPTIONS = {
    chrome: false,
    fonts: ['Inter:wght@400;600'],
    stylesheets: ['https://example.test/probe.css']
  }.freeze
  VARIANT_DSL = <<~RUBY
    use_stylesheet ".probe-inline { color: rebeccapurple; }"
    layout_slot :aside do
      text "slot probe"
    end
    #{PROBE_DSL}
  RUBY

  # A third probe, for theme_overrides: (an App.new kwarg, so only the hosts
  # that render a real App): one accent token and one surface token, on
  # :default and on :doc (whose own dark block an accent override must beat),
  # so the generated override block is recorded per host.
  OVERRIDES_HOSTS = %i[standalone export].freeze
  OVERRIDES_THEMES = %i[default doc].freeze
  OVERRIDES = { color_primary: '#a21caf', color_bg: '#fdf4ff' }.freeze

  # A fourth: a theme registered from a hash (light, dark:, css:, a font),
  # rendered as the main probe on the hosts that can name a registered theme,
  # so a new theme's whole page (body classes, head, CSS) is gated.
  REGISTERED_THEME = :harbor
  REGISTERED_HOSTS = %i[standalone canvas export].freeze
  # The main probe without its ide_shell: the IDE CSS is gated by every
  # built-in theme already, and another copy would only grow the CSS store.
  REGISTERED_DSL = PROBE_DSL.split("ide_shell").first

  # Theme::Presets CSS, which no built-in theme reaches (see EXCLUSIONS).
  PRESET = :editorial

  ROOT = File.expand_path('../fixtures/page_goldens', __dir__)
  # The CSS store is sharded by the first two hex digits of each block's
  # digest (css_blocks/<xx>.css), so no fixture file approaches the git
  # hygiene hook's size limit (bin/check_git_hygiene MAX_FILE_BYTES): a
  # shard holds only the blocks whose digest starts with its name.
  CSS_STORE_DIR = 'css_blocks'
  SHARD_DIGITS = 2

  module_function

  # @return [Hash{String=>String}] golden path (relative to ROOT) => content
  def render_all
    pages = {}
    HOSTS.each do |host|
      THEMES.each do |theme|
        html = send("render_#{host}", theme)
        unless BROWSER_FILLED.include?(host) || (html.include?('Heads up') && html.include?('sw-ide-shell'))
          raise "#{host}/#{theme} did not render the probe"
        end

        pages["#{host}/#{theme}.txt"] = record(html)
      end
    end
    VARIANT_HOSTS.each do |host|
      pages["#{host}/variant_#{VARIANT_THEME}.txt"] = send("render_variant_#{host}")
    end
    OVERRIDES_HOSTS.product(OVERRIDES_THEMES).each do |host, theme|
      pages["#{host}/overrides_#{theme}.txt"] = send("render_overrides_#{host}", theme)
    end
    with_registered_theme do
      REGISTERED_HOSTS.each do |host|
        html = with_probe_dsl(REGISTERED_DSL) { send("render_#{host}", REGISTERED_THEME) }
        pages["#{host}/registered_#{REGISTERED_THEME}.txt"] = record(html)
      end
    end
    pages["presets/#{PRESET}.txt"] = record_css_only(StreamWeaver::Theme::Presets.generate_preset_css(PRESET))
    pages['extension/base_stylesheet.txt'] = record_css_only(StreamWeaver::CSS.base_stylesheet)
    pages.merge(css_store_files)
  end

  # --- hosts ---------------------------------------------------------------

  def render_standalone(theme)
    dsl = probe_dsl
    app = StreamWeaver::App.new('Page probe', theme: theme) { instance_eval(dsl) }
    state = {}
    app.rebuild_with_state(state)
    StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
  end

  def render_canvas(theme)
    server = StreamWeaver::Canvas::BridgeServer
    previous = server.bridge
    server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    server.bridge.create_session('probe', theme: theme)
    server.bridge.handle_claude_message(type: 'push', name: 'probe', dsl: probe_dsl)
    rack_get(server, '/canvas/probe')
  ensure
    server.bridge = previous
  end

  def render_reader(theme)
    reader = StreamWeaver::Canvas::Reader
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'probe.rb'), probe_dsl)
      previous_list = reader.file_list
      reader.configure_files!(reader::FileList.build([dir]))
      reader.configure_defaults!(theme: theme)
      # The doc's own path reaches the body (Save-as-doc widget); pin it.
      rack_get(reader, '/?file=0').gsub(File.realpath(dir), '<tmpdir>').gsub(dir, '<tmpdir>')
    ensure
      reader.configure_files!(previous_list)
      reader.configure_defaults!
    end
  end

  def render_export(theme)
    StreamWeaver::Export::HtmlExporter.from_dsl(probe_dsl, theme: theme).to_html
  end

  # The /live session page (Service), which takes its theme from ?theme=.
  def render_live(theme)
    rack_get(StreamWeaver::Service, "/live/page-probe?theme=#{theme}")
  ensure
    StreamWeaver::Service.live_sessions.delete('page-probe')
  end

  # Runs every OpalBuilder step except the compile (see EXCLUSIONS), with
  # mermaid pinned to a local stub so the head does not depend on whether
  # vendor/js/mermaid.min.js happens to be present on this machine.
  #
  # OpalBuilder has no public build without the compile, so this depends on
  # its internals: the @mermaid_source_path ivar and the private steps
  # copy_morphdom, copy_marked, copy_browser_assets, write_theme_css and
  # write_index_html (opal/builder.rb). Its warnings are recorded, not hidden.
  def render_opal(theme)
    Dir.mktmpdir do |dir|
      app_file = File.join(dir, 'page_probe.rb')
      File.write(app_file, "app 'Page probe' do\n#{probe_dsl}end\n")
      mermaid_stub = File.join(dir, 'mermaid.min.js')
      File.write(mermaid_stub, '')
      out = File.join(dir, 'dist')
      builder = StreamWeaver::Opal::OpalBuilder.new(app_file, output_dir: out, theme: theme)
      builder.instance_variable_set(:@mermaid_source_path, mermaid_stub)
      FileUtils.mkdir_p(out)
      warnings = capture_warnings do
        %i[copy_morphdom copy_marked copy_browser_assets write_theme_css write_index_html]
          .each { |step| builder.send(step) }
      end
      html = File.read(File.join(out, 'index.html'))
      # The linked sw-theme.css is the page's CSS; record it as a head block.
      html.sub!('<link rel="stylesheet" href="sw-theme.css">',
                "<style>#{File.read(File.join(out, 'sw-theme.css'))}</style>") or
        raise 'opal index.html no longer links sw-theme.css; update PageGoldens.render_opal'
      [html, warnings]
    end
  end

  # --- the variant probe ---------------------------------------------------

  def variant_app
    app = StreamWeaver::App.new('Page probe', theme: VARIANT_THEME, **VARIANT_APP_OPTIONS)
    app.instance_eval(VARIANT_DSL)
    app
  end

  def render_variant_standalone
    app = variant_app
    record(StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call)
  end

  # An htmx response: no <head>, so only its <link>, <script> and <style> tags.
  def render_variant_standalone_partial
    app = variant_app
    html = StreamWeaver::Views::AppContentView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
    "# fragment <link>, <script> and <style> tags, in document order\n" \
      "#{placeholders(html).lines.map(&:chomp).grep(ASSET_TAG).join("\n")}\n"
  end

  def render_variant_canvas
    record(with_probe_dsl(VARIANT_DSL) { render_canvas(VARIANT_THEME) })
  end

  def render_variant_reader
    record(with_probe_dsl(VARIANT_DSL) { render_reader(VARIANT_THEME) })
  end

  def render_variant_export
    record(StreamWeaver::Export::HtmlExporter.new(variant_app).to_html)
  end

  def render_variant_opal
    record(with_probe_dsl(VARIANT_DSL) { render_opal(VARIANT_THEME) })
  end

  # --- the theme_overrides probe -------------------------------------------

  def overrides_app(theme)
    app = StreamWeaver::App.new('Page probe', theme: theme, theme_overrides: OVERRIDES)
    app.instance_eval(PROBE_DSL)
    app
  end

  def render_overrides_standalone(theme)
    record(StreamWeaver::Views::AppView.new(overrides_app(theme), {}, StreamWeaver::Adapter::AlpineJS.new).call)
  end

  def render_overrides_export(theme)
    record(StreamWeaver::Export::HtmlExporter.new(overrides_app(theme)).to_html)
  end

  # --- the registered-theme probe ------------------------------------------

  # Registered for the block only, so no other spec sees it.
  def with_registered_theme
    StreamWeaver.register_theme REGISTERED_THEME,
                                { color_primary: '#0e7490', color_bg: '#f7fafa' },
                                dark: { color_primary: '#22d3ee', color_bg: '#0b1416' },
                                fonts: ['Inter:wght@400;600'], label: 'Harbor',
                                css: "body.sw-theme-#{REGISTERED_THEME} h2 { letter-spacing: -0.01em; }"
    yield
  ensure
    StreamWeaver.themes.delete(REGISTERED_THEME)
  end

  # The fragment hosts read PROBE_DSL; swap in the variant for one render.
  def with_probe_dsl(dsl)
    @probe_dsl = dsl
    yield
  ensure
    @probe_dsl = nil
  end

  def probe_dsl
    @probe_dsl || PROBE_DSL
  end

  # --- recording -----------------------------------------------------------

  ASSET_TAG = /\A<(link|script|style)\b/

  # @param rendered [String, Array(String, String)] the page, or [page, build warnings]
  def record(rendered)
    html, warnings = rendered
    head = html[%r{<head>(.*?)</head>}m, 1] or raise "no <head> in render"
    body = html.split('</head>', 2).last
    body_class = body[/<body[^>]*\bclass="([^"]*)"/, 1].to_s
    body_assets = placeholders(body).lines.map(&:chomp).grep(ASSET_TAG)

    text = <<~TEXT
      # body class
      #{body_class}
      # head (one tag per line; <style> and inline <script> bodies are replaced by digests)
      #{placeholders(head)}
      # body <link>, <script> and <style> tags, in document order
      #{body_assets.join("\n")}
    TEXT
    warnings ? "#{text}# build warnings\n#{warnings}" : text
  end

  def record_css_only(css)
    "# CSS (#{css.bytesize} bytes)\n#{store(css)}\n"
  end

  # One left-to-right scan, so a "<script>" written inside an HTML comment
  # is consumed with the comment instead of opening a script.
  TOKEN = %r{<!--.*?-->|(<style[^>]*>)(.*?)</style>|(<script(?![^>]*\bsrc=)[^>]*>)(.*?)</script>}m

  # Replaces each <style> body with "[css <digest>]" (content kept in the
  # store) and each inline <script> body with "[script <digest>, N bytes]".
  # Returns the fragment one tag per line.
  def placeholders(fragment)
    text = fragment.gsub(TOKEN) do
      style_tag, style_body, script_tag, script_body = Regexp.last_match.captures
      if style_tag
        "#{style_tag}#{store(style_body)}</style>"
      elsif script_tag
        "#{script_tag}[script #{digest(script_body)}, #{script_body.bytesize} bytes]</script>"
      else
        Regexp.last_match(0)
      end
    end
    text.gsub(/>\s*</, ">\n<").lines.map(&:strip).reject(&:empty?).join("\n")
  end

  # CSS blocks are stored once, in first-seen order, so a change to a shared
  # block (master_theme_css, say) is one in-place hunk in its css_blocks shard
  # instead of thirty copies.
  def store(css)
    key = digest(css)
    css_blocks[key] ||= css
    "[css #{key}]"
  end

  def css_blocks
    @css_blocks ||= {}
  end

  # @return [Hash{String=>String}] shard path => its blocks, in first-seen order
  def css_store_files
    css_blocks.group_by { |key, _| key[0, SHARD_DIGITS] }.sort.to_h do |shard, blocks|
      text = blocks.map { |key, css| "/* ==== css #{key} (#{css.bytesize} bytes) ==== */\n#{css.strip}\n" }.join("\n")
      ["#{CSS_STORE_DIR}/#{shard}.css", text]
    end
  end

  def digest(text)
    Digest::SHA256.hexdigest(text)[0, 12]
  end

  def reset!
    @css_blocks = {}
  end

  def rack_get(app, path)
    response = Rack::MockRequest.new(app).get(path, 'HTTP_HOST' => 'localhost')
    raise "GET #{path} answered #{response.status}" unless response.status == 200

    response.body
  end

  # Returns what the block warned, and still passes it through to $stderr.
  def capture_warnings
    previous = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    captured = $stderr.string
    $stderr = previous
    $stderr.write(captured)
  end
end
