# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'rubygems/installer'
require 'rubygems/package'
require 'tmpdir'

RSpec.describe 'built-in SlimGraphR diagrams' do
  let(:gemspec) do
    Gem::Specification.load(File.expand_path('../stream_weaver.gemspec', __dir__))
  end

  def install_package(specification, source_root:, gem_home:, package_path:)
    Dir.chdir(source_root) do
      Gem::Package.build(specification, true, false, package_path)
    end
    Gem::Installer.at(
      package_path,
      install_dir: gem_home,
      wrappers: false,
      document: []
    ).install
  end

  it 'declares the compatible diagram engine as a runtime dependency' do
    dependency = gemspec.runtime_dependencies.find { |candidate| candidate.name == 'slim_graph_r' }

    expect(dependency).not_to be_nil
    expect(dependency.requirement).to eq(Gem::Requirement.new('~> 0.30.0'))
    expect(gemspec.required_ruby_version).to eq(Gem::Requirement.new('>= 3.1'))
  end

  it 'loads diagram into every shared-DSL consumer while preserving generic extensions' do
    lib_dir = File.expand_path('../lib', __dir__)
    script = <<~'RUBY'
      require 'stream_weaver'
      require 'stream_weaver/canvas/bridge'
      require 'stream_weaver/canvas/reader'
      require 'stream_weaver/export/html_exporter'

      dsl = <<~'DSL'
        diagram :architecture, title: 'Built in' do
          node :source
          node :result
          flow :source, :result
        end
      DSL

      app = StreamWeaver::App.new('App')
      app.instance_eval(dsl)
      app_html = StreamWeaver::ComponentRenderer.render_html(
        StreamWeaver::Adapter::AlpineJS.new,
        app.components
      )

      canvas = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, dsl, session_name: 'builtin')
      reader_html = StreamWeaver::Canvas::Reader.render_doc(dsl).html
      export_html = StreamWeaver::Export::HtmlExporter.from_dsl(dsl).to_html

      StreamWeaver.register_extension(:third_party_probe)

      puts [app_html, canvas.html, reader_html, export_html].all? { |html| html.include?('<svg') }
      puts canvas.error.nil?
      puts StreamWeaver::Extensions.registered?(:third_party_probe)
      puts $LOADED_FEATURES.any? { |path| path.end_with?('/slim_graph_r/stream_weaver.rb') }
    RUBY
    env = {
      'BUNDLE_GEMFILE' => nil,
      'RUBYLIB' => nil,
      'RUBYOPT' => nil,
      'SW_NO_OPEN' => '1',
      'SW_NO_AUTO_RESTART' => '1'
    }

    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-I', lib_dir, '-e', script)

    expect(status).to be_success, stderr
    expect(stdout.lines.map(&:strip)).to eq(%w[true true true true])
  end

  it 'supports requiring the SlimGraphR adapter before StreamWeaver completes loading' do
    lib_dir = File.expand_path('../lib', __dir__)
    script = <<~'RUBY'
      require 'slim_graph_r/stream_weaver'
      app = StreamWeaver::App.new('Direct adapter')
      app.instance_eval("diagram(:architecture) { node :ready }")
      puts app.components.last.class.name
    RUBY
    env = { 'BUNDLE_GEMFILE' => nil, 'RUBYLIB' => nil, 'RUBYOPT' => nil }

    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-I', lib_dir, '-e', script)

    expect(status).to be_success, stderr
    expect(stdout.strip).to eq('SlimGraphR::StreamWeaverComponent')
  end

  it 'loads both built gems from an isolated install directory' do
    Dir.mktmpdir('stream-weaver-slim-graph-package') do |dir|
      gem_home = File.join(dir, 'gems')
      stream_weaver_package = File.join(dir, 'stream_weaver.gem')
      slim_graph_package = File.join(dir, 'slim_graph_r.gem')
      slim_graph_spec = Gem::Specification.find_by_name('slim_graph_r', gemspec.dependencies
        .find { |dependency| dependency.name == 'slim_graph_r' }.requirement)
      packaged_slim_graph_spec = slim_graph_spec.dup
      packaged_slim_graph_spec.files = Dir.chdir(slim_graph_spec.full_gem_path) do
        Dir['**/*'].select { |path| File.file?(path) }
      end

      install_package(
        packaged_slim_graph_spec,
        source_root: slim_graph_spec.full_gem_path,
        gem_home: gem_home,
        package_path: slim_graph_package
      )
      install_package(
        gemspec,
        source_root: File.expand_path('..', __dir__),
        gem_home: gem_home,
        package_path: stream_weaver_package
      )

      script = <<~'RUBY'
        gem 'stream_weaver'
        require 'stream_weaver'
        app = StreamWeaver::App.new('Installed package')
        app.instance_eval("diagram(:architecture) { node :installed }")
        puts Gem.loaded_specs.fetch('stream_weaver').full_gem_path
        puts Gem.loaded_specs.fetch('slim_graph_r').full_gem_path
        puts app.components.last.diagram.to_svg.include?('<svg')
      RUBY
      env = {
        'GEM_HOME' => gem_home,
        'GEM_PATH' => ([gem_home] + Gem.path).uniq.join(File::PATH_SEPARATOR),
        'BUNDLE_GEMFILE' => nil,
        'RUBYLIB' => nil,
        'RUBYOPT' => nil,
        'SW_NO_OPEN' => '1',
        'SW_NO_AUTO_RESTART' => '1'
      }

      stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, '-e', script, chdir: dir)
      lines = stdout.lines.map(&:strip)
      installed_root = File.realpath(gem_home)

      expect(status).to be_success, stderr
      expect(lines[0]).to start_with(installed_root)
      expect(lines[1]).to start_with(installed_root)
      expect(lines[2]).to eq('true')
    end
  ensure
    Gem::Specification.reset
  end
end
