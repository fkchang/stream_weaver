# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'stream_weaver/university/course'
require 'stream_weaver/university/course_catalog'

RSpec.describe StreamWeaver::University::CourseCatalog do
  Provider = Struct.new(:courses)

  around do |example|
    StreamWeaver::Extensions.reset!
    example.run
  ensure
    StreamWeaver::Extensions.reset!
  end

  def course(id: 'diagram-intent', title: 'Diagram Intent', blurb: 'Choose diagrams by intent.',
             steps: [{ number: 1, title: 'Choose a diagram' }], demo_resolver: ->(name) { name })
    { id: id, title: title, blurb: blurb, steps: steps, demo_resolver: demo_resolver }
  end

  it 'normalizes an immutable built-in course followed by registered provider courses' do
    StreamWeaver.register_extension(
      :slim_graph_r,
      course_provider: Provider.new([course])
    )

    catalog = described_class.build
    getting_started, diagram_intent = catalog

    expect(catalog.map(&:id)).to eq(%w[getting-started diagram-intent])
    expect(getting_started.steps).to eq(StreamWeaver::University::Course::GETTING_STARTED_STEPS)
    expect(getting_started.demo_resolver.call('dashboard')).to eq(
      StreamWeaver::University::Demos.path('dashboard')
    )
    expect(diagram_intent.title).to eq('Diagram Intent')
    expect(diagram_intent.steps.map { |step| step[:number] }).to eq([1])
    expect(diagram_intent.demo_resolver.call('diagram')).to eq('diagram')
    expect(catalog).to be_frozen
    expect(diagram_intent).to be_frozen
    expect { diagram_intent.title << ' changed' }.to raise_error(FrozenError)
    expect(diagram_intent.steps).to be_frozen
    expect(diagram_intent.steps.first).to be_frozen
  end

  it 'strips text fields and rejects IDs that collide after canonicalization' do
    StreamWeaver.register_extension(:alpha, course_provider: Provider.new([course(id: '  shared  ', title: '  Diagram Intent  ', blurb: '  Choose diagrams.  ')]))
    StreamWeaver.register_extension(:beta, course_provider: Provider.new([course(id: 'shared')]))

    expect { described_class.build }
      .to raise_error(described_class::InvalidProviderError, /beta.*:id/i)

    StreamWeaver::Extensions.reset!
    StreamWeaver.register_extension(:alpha, course_provider: Provider.new([course(id: '  diagram-intent  ', title: '  Diagram Intent  ', blurb: '  Choose diagrams.  ')]))
    normalized = described_class.build.last
    expect([normalized.id, normalized.title, normalized.blurb]).to eq(
      ['diagram-intent', 'Diagram Intent', 'Choose diagrams.']
    )
  end

  it 'accepts only literal Hash course records without attempting conversion' do
    converting_record = Class.new do
      def to_h
        raise 'must not convert'
      end
    end.new
    StreamWeaver.register_extension(:slim_graph_r, course_provider: Provider.new([converting_record]))

    expect { described_class.build }
      .to raise_error(described_class::InvalidProviderError, /slim_graph_r.*:course/i)
  end

  it 'rejects unsupported mutable step values with the provider and :steps' do
    StreamWeaver.register_extension(
      :slim_graph_r,
      course_provider: Provider.new([course(steps: [{ number: 1, metadata: Object.new }])])
    )

    expect { described_class.build }
      .to raise_error(described_class::InvalidProviderError, /slim_graph_r.*:steps/i)
  end

  it 'wraps a duplicated frozen demo resolver owned by the normalized definition' do
    resolver = Struct.new(:path) do
      def call(name)
        "#{path}/#{name}"
      end
    end.new('/original')
    StreamWeaver.register_extension(:slim_graph_r, course_provider: Provider.new([course(demo_resolver: resolver)]))

    normalized_resolver = described_class.build.last.demo_resolver
    resolver.path = '/changed'

    expect(normalized_resolver).to be_frozen
    expect(normalized_resolver.call('demo')).to eq('/original/demo')
    expect { normalized_resolver.instance_variable_set(:@changed, true) }.to raise_error(FrozenError)
  end

  it 'defines Course::Definition when course is required before the catalog' do
    script = <<~RUBY
      require 'stream_weaver/university/course'
      abort 'definition missing' unless StreamWeaver::University::Course.const_defined?(:Definition)
      require 'stream_weaver/university/course_catalog'
      puts 'clean course require order'
    RUBY
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-I', File.expand_path('../../lib', __dir__), '-e', script)

    expect(status).to be_success, stderr
    expect(stdout).to include('clean course require order')
  end

  it 'orders providers by stable extension ID while preserving each provider course order' do
    StreamWeaver.register_extension(:zeta, course_provider: Provider.new([course(id: 'zeta-first'), course(id: 'zeta-second')]))
    StreamWeaver.register_extension(:alpha, course_provider: Provider.new([course(id: 'alpha-first')]))

    expect(described_class.build.map(&:id)).to eq(
      %w[getting-started alpha-first zeta-first zeta-second]
    )
  end

  it 'does not invent courses when no extension provides one' do
    StreamWeaver.register_extension(:plain_extension)

    expect(described_class.build.map(&:id)).to eq(['getting-started'])
  end

  it 'rejects invalid provider data with the provider ID and failing field' do
    StreamWeaver.register_extension(:slim_graph_r, course_provider: Provider.new([course(title: '  ')]))

    expect { described_class.build }
      .to raise_error(described_class::InvalidProviderError, /slim_graph_r.*title/i)
  end

  it 'rejects duplicate course IDs with the provider ID and id field' do
    StreamWeaver.register_extension(:alpha, course_provider: Provider.new([course(id: 'shared')]))
    StreamWeaver.register_extension(:beta, course_provider: Provider.new([course(id: 'shared')]))

    expect { described_class.build }
      .to raise_error(described_class::InvalidProviderError, /beta.*id/i)
  end
end
