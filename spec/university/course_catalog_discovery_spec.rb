# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'rubygems/installer'
require 'rubygems/package'
require 'tmpdir'

RSpec.describe 'University extension discovery at the course catalog boundary' do
  def install_extension(gem_home, name:, loader:, source:)
    version = '1.0.0'
    Dir.mktmpdir("#{name}-build") do |source_root|
      loader_path = File.join(source_root, 'lib', "#{loader}.rb")
      FileUtils.mkdir_p(File.dirname(loader_path))
      File.write(loader_path, source)

      specification = Gem::Specification.new do |spec|
        spec.name = name
        spec.version = version
        spec.summary = 'StreamWeaver extension discovery fixture'
        spec.authors = ['StreamWeaver specs']
        spec.files = ["lib/#{loader}.rb"]
        spec.require_paths = ['lib']
        spec.metadata['stream_weaver.extensions.v1'] = loader
      end
      gem_path = Dir.chdir(source_root) do
        File.join(source_root, Gem::Package.build(specification, true))
      end
      Gem::Installer.at(
        gem_path,
        install_dir: gem_home,
        wrappers: false,
        document: []
      ).install
    end
  end

  def with_installed_extensions
    Dir.mktmpdir('stream-weaver-installed-extensions') do |gem_home|
      install_extension(
        gem_home,
        name: 'aaa_broken_university_extension',
        loader: 'aaa_broken_university_extension/extension',
        source: <<~RUBY
          StreamWeaver.register_extension(:ghost_course, course_provider: Object.new)
          raise LoadError, 'broken fixture dependency'
        RUBY
      )
      install_extension(
        gem_home,
        name: 'zzz_healthy_university_extension',
        loader: 'zzz_healthy_university_extension/extension',
        source: <<~RUBY
          module HealthyUniversityFixture
            DEMO = File.expand_path('demo.rb', __dir__)
            File.write(DEMO, "puts 'fixture demo'\\n")

            Provider = Struct.new(:courses)
            COURSE = {
              id: 'fixture-diagram-intent',
              title: 'Fixture Diagram Course',
              blurb: 'Choose diagrams by intent.',
              steps: [{ number: 1, title: 'Choose a diagram', prompt: 'Choose by intent.' }],
              demo_resolver: ->(_name) { DEMO }
            }
          end

          StreamWeaver.register_extension(
            :healthy_course,
            course_provider: HealthyUniversityFixture::Provider.new([HealthyUniversityFixture::COURSE])
          )
        RUBY
      )

      env = {
        'GEM_HOME' => gem_home,
        'GEM_PATH' => ([gem_home] + Gem.path).uniq.join(File::PATH_SEPARATOR),
        'RUBYOPT' => nil,
        'RUBYLIB' => nil,
        'BUNDLE_GEMFILE' => nil,
        'SLIM_GRAPH_R_SOURCE' => nil,
        'SLIM_GRAPH_R_SPEC' => Gem.loaded_specs.fetch('slim_graph_r').loaded_from,
        'STREAMWEAVER_UNIVERSITY_PROGRESS' => File.join(gem_home, 'progress.yml')
      }
      yield env
    end
  end

  def ruby_command(script)
    ruby_gems_bootstrap = <<~RUBY
      require 'stream_weaver'
      # This spec runs under Bundler/RVM, which caches the parent process's
      # specification directories before the subprocess GEM_HOME override.
      # Load the gems installed above into that fresh process's RubyGems view.
      fixture_specs = Dir[File.join(ENV.fetch('GEM_HOME'), 'specifications', '*.gemspec')].filter_map do |path|
        Gem::Specification.load(path)
      end
      fixture_specs << Gem::Specification.load(ENV.fetch('SLIM_GRAPH_R_SPEC'))
      fixture_specs.flat_map(&:full_require_paths).reverse_each { |path| $LOAD_PATH.unshift(path) }
      fixture_names = fixture_specs.map(&:name)
      installed_specs = Gem::Specification.to_a.reject { |spec| fixture_names.include?(spec.name) }
      Gem::Specification.define_singleton_method(:each) do |&block|
        specs = fixture_specs + installed_specs
        block ? specs.each(&block) : specs.each
      end
    RUBY
    slim_graph_r_lib = Gem.loaded_specs.fetch('slim_graph_r').full_require_paths.first
    [RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-I', slim_graph_r_lib, '-e', ruby_gems_bootstrap + script]
  end

  def capture_fresh(env, script)
    Bundler.with_unbundled_env { Open3.capture3(env, *ruby_command(script)) }
  end

  it 'lists an installed metadata-declared course while isolating a broken loader' do
    script = <<~RUBY
      require 'stream_weaver/university/course_catalog'
      catalog = StreamWeaver::University::CourseCatalog.build
      puts catalog.map(&:id).join(',')
      puts StreamWeaver::Extensions.registered?(:ghost_course)
    RUBY

    with_installed_extensions do |env|
      stdout, stderr, status = capture_fresh(env, script)

      expect(status).to be_success, stderr
      expect(stdout.lines.map(&:strip)).to eq([
        'getting-started,fixture-diagram-intent,diagram-intent',
        'false'
      ])
    end
  end

  it 'resolves university-demo --course through discovery in a fresh CLI process' do
    executable = File.expand_path('../../exe/streamweaver', __dir__)
    script = <<~RUBY
      ARGV.replace(%w[university-demo diagram --course fixture-diagram-intent])
      load #{executable.inspect}
    RUBY
    with_installed_extensions do |env|
      stdout, stderr, status = capture_fresh(env, script)

      expect(status).to be_success, stderr
      expect(stdout.strip).to end_with('/zzz_healthy_university_extension/demo.rb')
      expect(File).to exist(stdout.strip)
    end
  end

  it 'renders an installed course on the University canvas in a fresh process' do
    canvas_path = File.expand_path('../../lib/stream_weaver/university/canvas.rb', __dir__)
    script = <<~RUBY
      require 'stream_weaver'
      html = StreamWeaver::CLI.render_dsl_to_html(File.read(#{canvas_path.inspect}), session_name: 'discovery-spec')
      puts html.include?('Fixture Diagram Course')
      puts html.include?('run-course-fixture-diagram-intent-1')
      puts StreamWeaver::Extensions.registered?(:ghost_course)
    RUBY

    with_installed_extensions do |env|
      stdout, stderr, status = capture_fresh(env, script)

      expect(status).to be_success, stderr
      expect(stdout.lines.map(&:strip)).to eq(%w[true true false])
    end
  end

  it 'resolves the installed course from the listener in a fresh process' do
    script = <<~RUBY
      require 'stream_weaver/university/listener'
      StreamWeaver::University::Listener.define_singleton_method(:repush) { |**| }
      StreamWeaver::University::Listener.university_done!(1, course_id: 'fixture-diagram-intent')
      progress = StreamWeaver::University::Progress.load(course_id: 'fixture-diagram-intent')
      puts progress.done?(1)
    RUBY

    with_installed_extensions do |env|
      stdout, stderr, status = capture_fresh(env, script)

      expect(status).to be_success, stderr
      expect(stdout.strip).to eq('true')
    end
  end
end
