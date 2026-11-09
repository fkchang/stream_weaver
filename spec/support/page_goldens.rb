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
  THEMES = %i[default dashboard document dark doc ide].freeze
  HOSTS  = %i[standalone canvas reader export opal].freeze

  # Hosts, or parts of a host, that cannot be rendered without a browser or
  # a full compile. Listed here (and printed by the spec) so nothing is
  # silently skipped.
  EXCLUSIONS = {
    'opal app.js' => 'compiling app.js needs the opal compiler and takes seconds per theme; ' \
                     'the head, body class and sw-theme.css are produced by the builder steps ' \
                     'that run without it (write_theme_css, write_index_html), so those are recorded',
    'opal runtime theme' => 'a theme the Opal app applies at runtime happens in the browser; the ' \
                            'build-time body class comes from --theme, which the builder treats as ' \
                            'a Theme::Presets name (none of the six built-ins is one)',
    'extension head' => 'the extension page is assembled in the browser by sandbox.js; only its ' \
                        'framework CSS input, CSS.base_stylesheet (bin/build_extension), is recorded'
  }.freeze

  PROBE_DSL = <<~RUBY
    header1 "Page probe"
    button "Go"
    table [{ "name" => "alpha", "value" => 1 }]
    callout "Heads up", variant: :info
  RUBY

  ROOT = File.expand_path('../fixtures/page_goldens', __dir__)
  CSS_STORE = File.join(ROOT, 'css_blocks.css')

  module_function

  # @return [Hash{String=>String}] golden path (relative to ROOT) => content
  def render_all
    pages = {}
    HOSTS.each do |host|
      THEMES.each do |theme|
        html = send("render_#{host}", theme)
        # Opal renders its body in the browser; every other host must show the probe.
        raise "#{host}/#{theme} did not render the probe" unless host == :opal || html.include?('Heads up')

        pages["#{host}/#{theme}.txt"] = record(html)
      end
    end
    pages['extension/base_stylesheet.txt'] = record_css_only(StreamWeaver::CSS.base_stylesheet)
    pages.merge('css_blocks.css' => css_store_text)
  end

  # --- hosts ---------------------------------------------------------------

  def render_standalone(theme)
    app = StreamWeaver::App.new('Page probe', theme: theme) { instance_eval(PROBE_DSL) }
    state = {}
    app.rebuild_with_state(state)
    StreamWeaver::Views::AppView.new(app, state, StreamWeaver::Adapter::AlpineJS.new).call
  end

  def render_canvas(theme)
    server = StreamWeaver::Canvas::BridgeServer
    previous = server.bridge
    server.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
    server.bridge.create_session('probe', theme: theme)
    server.bridge.handle_claude_message(type: 'push', name: 'probe', dsl: PROBE_DSL)
    rack_get(server, '/canvas/probe')
  ensure
    server.bridge = previous
  end

  def render_reader(theme)
    reader = StreamWeaver::Canvas::Reader
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'probe.rb'), PROBE_DSL)
      previous_list = reader.file_list
      reader.configure_files!(reader::FileList.build([dir]))
      reader.configure_defaults!(theme: theme)
      rack_get(reader, '/?file=0')
    ensure
      reader.configure_files!(previous_list)
      reader.configure_defaults!
    end
  end

  def render_export(theme)
    StreamWeaver::Export::HtmlExporter.from_dsl(PROBE_DSL, theme: theme).to_html
  end

  # Runs every OpalBuilder step except the compile (see EXCLUSIONS), with
  # mermaid pinned to a local stub so the head does not depend on whether
  # vendor/js/mermaid.min.js happens to be present on this machine.
  def render_opal(theme)
    Dir.mktmpdir do |dir|
      app_file = File.join(dir, 'page_probe.rb')
      File.write(app_file, "app 'Page probe' do\n#{PROBE_DSL}end\n")
      mermaid_stub = File.join(dir, 'mermaid.min.js')
      File.write(mermaid_stub, '')
      out = File.join(dir, 'dist')
      builder = StreamWeaver::Opal::OpalBuilder.new(app_file, output_dir: out, theme: theme)
      builder.instance_variable_set(:@mermaid_source_path, mermaid_stub)
      FileUtils.mkdir_p(out)
      silence_warnings do
        %i[copy_morphdom copy_marked copy_browser_assets write_theme_css write_index_html]
          .each { |step| builder.send(step) }
      end
      html = File.read(File.join(out, 'index.html'))
      # The linked sw-theme.css is the page's CSS; record it as a head block.
      html.sub('<link rel="stylesheet" href="sw-theme.css">',
               "<style>#{File.read(File.join(out, 'sw-theme.css'))}</style>")
    end
  end

  # --- recording -----------------------------------------------------------

  def record(html)
    head = html[%r{<head>(.*?)</head>}m, 1] or raise "no <head> in render"
    body = html.split('</head>', 2).last
    body_class = body[/<body[^>]*\bclass="([^"]*)"/, 1].to_s
    head_text, = placeholders(head)
    _, body_css = placeholders(body)

    <<~TEXT
      # body class
      #{body_class}
      # head (one tag per line; <style> and inline <script> bodies are replaced by digests)
      #{head_text}
      # body <style> blocks, in document order
      #{body_css.join("\n")}
    TEXT
  end

  def record_css_only(css)
    "# CSS (#{css.bytesize} bytes)\n#{store(css)}\n"
  end

  # One left-to-right scan, so a "<script>" written inside an HTML comment
  # is consumed with the comment instead of opening a script.
  TOKEN = %r{<!--.*?-->|(<style[^>]*>)(.*?)</style>|(<script(?![^>]*\bsrc=)[^>]*>)(.*?)</script>}m

  # Replaces each <style> body with "[css <digest>]" (content kept in the
  # store) and each inline <script> body with "[script <digest>, N bytes]".
  # Returns [one-tag-per-line text, list of css placeholders in order].
  def placeholders(fragment)
    css = []
    text = fragment.gsub(TOKEN) do
      style_tag, style_body, script_tag, script_body = Regexp.last_match.captures
      if style_tag
        "#{style_tag}#{store(style_body)}</style>".tap { |tag| css << tag }
      elsif script_tag
        "#{script_tag}[script #{digest(script_body)}, #{script_body.bytesize} bytes]</script>"
      else
        Regexp.last_match(0)
      end
    end
    lines = text.gsub(/>\s*</, ">\n<").lines.map(&:strip).reject(&:empty?)
    [lines.join("\n"), css]
  end

  # CSS blocks are stored once, in first-seen order, so a change to a shared
  # block (master_theme_css, say) is one in-place hunk in css_blocks.css
  # instead of thirty copies.
  def store(css)
    key = digest(css)
    css_blocks[key] ||= css
    "[css #{key}]"
  end

  def css_blocks
    @css_blocks ||= {}
  end

  def css_store_text
    css_blocks.map { |key, css| "/* ==== css #{key} (#{css.bytesize} bytes) ==== */\n#{css.strip}\n" }.join("\n")
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

  def silence_warnings
    previous = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = previous
  end
end
