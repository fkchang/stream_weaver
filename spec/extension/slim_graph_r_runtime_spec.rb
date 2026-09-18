# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'timeout'

RSpec.describe 'the packaged SlimGraphR extension runtime' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:runtime) { File.join(root, 'extension', 'vendor', 'sw-runtime.js') }
  let(:gallery) do
    local = File.expand_path('../../slim_graph_r/examples/stream_weaver/gallery.rb', root)
    installed = File.join(Gem::Specification.find_by_name('slim_graph_r').full_gem_path,
                          'examples', 'stream_weaver', 'gallery.rb')
    ENV.fetch('SLIM_GRAPH_R_GALLERY', File.file?(local) ? local : installed)
  end

  before(:all) do
    root = File.expand_path('../..', __dir__)
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.join(root, 'bin', 'build_extension'))
    raise "extension build failed:\n#{stdout}\n#{stderr}" unless status.success?
  end

  def atlas_examples
    source = File.read(gallery, encoding: 'UTF-8')
    source.scan(/example\.call\(:(\w+).*?<<~'RUBY'\),\n(.*?)^  RUBY$/mu).map do |type, ruby|
      [type, ruby.gsub(/^    /, '')]
    end
  end

  def capture_node(program, timeout: 10)
    stdout_text = stderr_text = nil
    status = nil

    Open3.popen3('node', '-e', program) do |stdin, stdout, stderr, wait_thread|
      stdin.close
      stdout_reader = Thread.new { stdout.read }
      stderr_reader = Thread.new { stderr.read }

      begin
        status = Timeout.timeout(timeout) { wait_thread.value }
      rescue Timeout::Error
        Process.kill('KILL', wait_thread.pid)
        wait_thread.value
        raise
      ensure
        stdout_text = stdout_reader.value
        stderr_text = stderr_reader.value
      end
    end

    [stdout_text, stderr_text, status]
  end

  it 'renders the complete saved Ruby gallery in one bounded static pass' do
    saved_ruby = File.read(gallery, encoding: 'UTF-8')
    expected_titles = atlas_examples.map do |_type, ruby|
      ruby.match(/diagram\s+:\w+,\s+title:\s+(['"])(.*?)\1/)[2]
    end
    marked = File.join(root, 'extension', 'vendor', 'marked.umd.js')
    heredoc_rewriter = File.join(root, 'extension', 'vendor', 'sw-heredoc-rewrite.js')

    program = <<~JS
      const fs = require("fs");
      const vm = require("vm");
      global.marked = require(#{marked.to_json});
      const { rewriteHeredocs } = require(#{heredoc_rewriter.to_json});
      vm.runInThisContext(fs.readFileSync(#{runtime.to_json}, "utf8"), { filename: #{runtime.to_json} });

      const appPrototype = Opal.StreamWeaver.App.$$prototype;
      const rebuildWithState = appPrototype.$rebuild_with_state;
      let builds = 0;
      appPrototype.$rebuild_with_state = function() {
        builds += 1;
        return rebuildWithState.apply(this, arguments);
      };

      const source = rewriteHeredocs(#{saved_ruby.to_json});
      const evalStarted = performance.now();
      Opal.eval(`app("Complete diagram atlas") do\n${source}\nend`);
      const evalMs = performance.now() - evalStarted;

      if (typeof SWRender.staticHtml !== "function") {
        throw new Error("SWRender.staticHtml() is required for saved document previews");
      }

      const renderStarted = performance.now();
      const html = SWRender.staticHtml();
      const renderMs = performance.now() - renderStarted;
      process.stdout.write(JSON.stringify({
        svg: (html.match(/<svg\\b/g) || []).length,
        title: (html.match(/<title\\b/g) || []).length,
        desc: (html.match(/<desc\\b/g) || []).length,
        titles: Array.from(html.matchAll(/<title[^>]*>(.*?)<\\/title>/g), match => match[1]),
        regions: (html.match(/id="sw-region-/g) || []).length,
        builds,
        remote: /(?:href|src)=["'](?:https?:)?\\/\\//.test(html),
        evalMs,
        renderMs
      }));
    JS

    stdout, stderr, status = capture_node(program)
    expect(status).to be_success, stderr
    expect(stderr).to be_empty
    result = JSON.parse(stdout)
    expect(result).to include(
      'svg' => 39, 'title' => 39, 'desc' => 39, 'regions' => 0, 'builds' => 1, 'remote' => false
    )
    expect(result.fetch('titles')).to eq(expected_titles)
    expect(result.fetch('renderMs')).to be <= 5_000
    RSpec.configuration.reporter.message(
      format('gallery timings: Opal.eval %.1f ms, SWRender.staticHtml %.1f ms',
             result.fetch('evalMs'), result.fetch('renderMs'))
    )
  end

  it 'renders the complete saved Ruby gallery in one bounded live pass with visible labels' do
    saved_ruby = File.read(gallery, encoding: 'UTF-8')
    expected_titles = atlas_examples.map do |_type, ruby|
      ruby.match(/diagram\s+:\w+,\s+title:\s+(['"])(.*?)\1/)[2]
    end
    marked = File.join(root, 'extension', 'vendor', 'marked.umd.js')
    heredoc_rewriter = File.join(root, 'extension', 'vendor', 'sw-heredoc-rewrite.js')

    program = <<~JS
      const fs = require("fs");
      const vm = require("vm");
      global.marked = require(#{marked.to_json});
      const { rewriteHeredocs } = require(#{heredoc_rewriter.to_json});
      vm.runInThisContext(fs.readFileSync(#{runtime.to_json}, "utf8"), { filename: #{runtime.to_json} });

      const appPrototype = Opal.StreamWeaver.App.$$prototype;
      const rebuildWithState = appPrototype.$rebuild_with_state;
      let builds = 0;
      appPrototype.$rebuild_with_state = function() {
        builds += 1;
        return rebuildWithState.apply(this, arguments);
      };

      const source = rewriteHeredocs(#{saved_ruby.to_json});
      const evalStarted = performance.now();
      Opal.eval(`app("Complete live diagram atlas") do\n${source}\nend`);
      const evalMs = performance.now() - evalStarted;
      const renderStarted = performance.now();
      const html = SWRender.html();
      const renderMs = performance.now() - renderStarted;
      const svgs = Array.from(html.matchAll(/<svg\\b[\\s\\S]*?<\\/svg>/g), match => match[0]);
      const labeled = svgs.filter(svg => Array.from(svg.matchAll(/<text\\b[^>]*>([\\s\\S]*?)<\\/text>/g))
        .some(match => match[1].replace(/<[^>]*>/g, "").trim().length > 0));
      process.stdout.write(JSON.stringify({
        svg: svgs.length,
        labeled: labeled.length,
        title: (html.match(/<title\\b/g) || []).length,
        desc: (html.match(/<desc\\b/g) || []).length,
        titles: Array.from(html.matchAll(/<title[^>]*>(.*?)<\\/title>/g), match => match[1]),
        regions: (html.match(/id="sw-region-/g) || []).length,
        builds,
        remote: /(?:href|src)=["'](?:https?:)?\\/\\//.test(html),
        evalMs,
        renderMs
      }));
    JS

    stdout, stderr, status = capture_node(program)
    expect(status).to be_success, stderr
    expect(stderr).to be_empty
    result = JSON.parse(stdout)
    expect(result).to include(
      'svg' => 39, 'labeled' => 39, 'title' => 39, 'desc' => 39, 'builds' => 1, 'remote' => false
    )
    expect(result.fetch('regions')).to be > 39
    expect(result.fetch('titles')).to eq(expected_titles)
    expect(result.fetch('renderMs')).to be <= 10_000
    RSpec.configuration.reporter.message(
      format('live gallery timings: Opal.eval %.1f ms, SWRender.html %.1f ms',
             result.fetch('evalMs'), result.fetch('renderMs'))
    )
  end

  it 'renders every packaged atlas type as accessible offline SVG through Opal' do
    expect(atlas_examples.length).to eq(39)

    program = <<~JS
      const fs = require("fs");
      const vm = require("vm");
      vm.runInThisContext(fs.readFileSync(#{runtime.to_json}, "utf8"), { filename: "sw-runtime.js" });

      const examples = #{atlas_examples.to_json};
      const results = [];
      for (const [type, source] of examples) {
        try {
          Opal.eval(`app(${JSON.stringify(`Atlas ${type}`)}) do\nrequire "slim_graph_r/stream_weaver"\n${source}\nend`);
          const html = SWRender.html();
          results.push({
            type,
            svg: (html.match(/<svg\\b/g) || []).length,
            title: (html.match(/<title\\b/g) || []).length,
            desc: (html.match(/<desc\\b/g) || []).length,
            labeled: Array.from(html.matchAll(/<text\\b[^>]*>([\\s\\S]*?)<\\/text>/g))
              .some(match => match[1].replace(/<[^>]*>/g, "").trim().length > 0),
            remote: /(?:href|src)=["'](?:https?:)?\\/\\//.test(html)
          });
        } catch (error) {
          results.push({ type, error: String(error && (error.stack || error.message || error)) });
          break;
        }
      }
      process.stdout.write(JSON.stringify(results));
    JS

    stdout, stderr, status = Open3.capture3('node', '-e', program)
    expect(status).to be_success, stderr
    expect(stderr).to be_empty
    results = JSON.parse(stdout)
    failure = results.find { |result| result['error'] }
    expect(failure).to be_nil, -> { "first failing atlas type: #{failure.fetch('type')}: #{failure.fetch('error')}" }
    expect(results.map { |result| result['type'] }).to eq(atlas_examples.map(&:first))
    expect(results).to all(include(
      'svg' => 1, 'title' => 1, 'desc' => 1, 'labeled' => true, 'remote' => false
    ))
  end

  it 'keeps ASCII and Unicode labels when Text.wrap runs through Opal' do
    program = <<~JS
      const fs = require("fs");
      const vm = require("vm");
      vm.runInThisContext(fs.readFileSync(#{runtime.to_json}, "utf8"), { filename: "sw-runtime.js" });
      const text = Opal.SlimGraphR.Text;
      process.stdout.write(JSON.stringify({
        ascii: text.$wrap("Architecture API", 10_000).join(""),
        unicode: text.$wrap("café 東京 e\\u0301", 10_000).join("")
      }));
    JS

    stdout, stderr, status = capture_node(program)
    expect(status).to be_success, stderr
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to eq(
      'ascii' => 'Architecture API',
      'unicode' => "café 東京 e\u0301"
    )
  end

  it 'converts an Org saved document containing the atlas through the bundled reader' do
    ruby = (["require 'slim_graph_r/stream_weaver'"] + atlas_examples.map(&:last)).join("\n")
    org = <<~ORG
      #+STREAMWEAVER_DSL: 1
      #+TITLE: Packaged Diagram Atlas

      #+begin_src ruby :streamweaver-raw t
      #{ruby}
      #+end_src
    ORG
    program = <<~JS
      const fs = require("fs");
      const vm = require("vm");
      vm.runInThisContext(fs.readFileSync(#{runtime.to_json}, "utf8"), { filename: "sw-runtime.js" });
      const ruby = Opal.StreamWeaver.Org.Reader.$to_dsl(#{org.to_json});
      Opal.eval(`app("Org atlas") do\n${ruby}\nend`);
      const html = SWRender.html();
      process.stdout.write(JSON.stringify({
        svg: (html.match(/<svg\\b/g) || []).length,
        title: (html.match(/<title\\b/g) || []).length,
        desc: (html.match(/<desc\\b/g) || []).length,
        remote: /(?:href|src)=["'](?:https?:)?\\/\\//.test(html)
      }));
    JS

    stdout, stderr, status = Open3.capture3('node', '-e', program)
    expect(status).to be_success, stderr
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to eq('svg' => 39, 'title' => 39, 'desc' => 39, 'remote' => false)
  end

  it 'keeps the diagram runtime inside the extension sandbox CSP' do
    manifest = JSON.parse(File.read(File.join(root, 'extension', 'manifest.json')))
    sandbox_html = File.read(File.join(root, 'extension', 'sandbox.html'))
    sandbox_js = File.read(File.join(root, 'extension', 'sandbox.js'))

    expect(manifest.dig('sandbox', 'pages')).to include('sandbox.html')
    expect(manifest.dig('content_security_policy', 'sandbox')).to include("script-src 'self' 'unsafe-eval'")
    expect(sandbox_html.scan(/<(?:script|link)[^>]+(?:src|href)="([^"]+)"/).flatten)
      .to all(satisfy { |path| !path.match?(%r{\A(?:https?:)?//}) })
    # The render path itself is pinned by spec/extension/live_runtime_spec.rb
    # (it moved from SWRender.staticHtml() + innerHTML to SWRuntime.start()
    # when the live runtime was wired up). What matters here is only that
    # rendering a diagram still reaches no network.
    expect(sandbox_js).not_to match(/\bfetch\s*\(/)
  end

  it 'fails the build explicitly when the selected SlimGraphR source lacks the browser entrypoint' do
    Dir.mktmpdir('slim-graph-r-missing-entrypoint') do |empty_lib|
      stdout, stderr, status = Open3.capture3(
        { 'SLIM_GRAPH_R_LIB' => empty_lib },
        RbConfig.ruby,
        File.join(root, 'bin', 'build_extension')
      )

      expect(status).not_to be_success
      expect("#{stdout}\n#{stderr}").to include('slim_graph_r/stream_weaver_opal.rb')
    end
  end
end
