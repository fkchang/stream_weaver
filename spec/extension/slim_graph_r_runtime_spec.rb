# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

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
    expect(results).to all(include('svg' => 1, 'title' => 1, 'desc' => 1, 'remote' => false))
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
