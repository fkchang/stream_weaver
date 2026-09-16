# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'

RSpec.describe StreamWeaver::Extensions do
  FakeSpecification = Struct.new(:name, :metadata, keyword_init: true)

  around do |example|
    described_class.reset!
    example.run
  ensure
    described_class.reset!
  end

  def spec(name, loader: nil)
    metadata = loader ? { 'stream_weaver.extensions.v1' => loader } : {}
    FakeSpecification.new(name: name, metadata: metadata)
  end

  describe '.discover' do
    it 'requires only metadata-declared loaders in deterministic gem-name order' do
      required = []

      result = described_class.discover(
        specifications: [
          spec('zeta', loader: 'zeta/stream_weaver'),
          spec('ignored'),
          spec('alpha', loader: 'alpha/stream_weaver')
        ],
        requireer: ->(loader) { required << loader }
      )

      expect(required).to eq(%w[alpha/stream_weaver zeta/stream_weaver])
      expect(result).to be_frozen
      expect(result.loaded).to be_frozen
      expect(result.loaded.first).to be_frozen
      expect { result.loaded.first.loader << '/changed' }.to raise_error(FrozenError)
      expect { result.loaded.first.gem_name << '-changed' }.to raise_error(FrozenError)
    end

    it 'does not require a loader again when discovery is repeated' do
      required = []
      specifications = [spec('alpha', loader: 'alpha/stream_weaver')]

      2.times do
        described_class.discover(
          specifications: specifications,
          requireer: ->(loader) { required << loader }
        )
      end

      expect(required).to eq(['alpha/stream_weaver'])
    end

    it 'rolls back partial registrations when a loader raises LoadError or StandardError' do
      [LoadError, RuntimeError].each_with_index do |error_class, index|
        loader = "broken/#{index}"
        result = described_class.discover(
          specifications: [spec("broken-#{index}", loader: loader)],
          requireer: lambda { |_loader|
            described_class.register(:partial_extension)
            raise error_class, 'broken extension loader'
          }
        )

        expect(result.failures.map(&:loader)).to eq([loader])
        expect(result.failures.first.error).to be_a(error_class)
        expect(described_class).not_to be_registered(:partial_extension)
      end
    end

    it 'replays a cached failure instead of requiring a failed loader again' do
      attempts = 0
      specifications = [spec('broken', loader: 'broken/stream_weaver')]

      first_result = described_class.discover(
        specifications: specifications,
        requireer: lambda { |_loader|
          attempts += 1
          described_class.register(:partial_extension)
          raise LoadError, 'broken extension loader'
        }
      )
      second_result = described_class.discover(
        specifications: specifications,
        requireer: ->(_loader) { raise 'failed loader was required again' }
      )

      expect(first_result.failures.map(&:loader)).to eq(['broken/stream_weaver'])
      expect(second_result.loaded).to be_empty
      expect(second_result.failures.first).to equal(first_result.failures.first)
      expect(attempts).to eq(1)
      expect(described_class).not_to be_registered(:partial_extension)
      expect(first_result).to be_frozen
      expect(first_result.failures).to be_frozen
      expect(first_result.failures.first).to be_frozen
      expect { first_result.failures.first.loader << '/changed' }.to raise_error(FrozenError)
      expect { first_result.failures.first.gem_name << '-changed' }.to raise_error(FrozenError)
    end

    it 'isolates a SyntaxError so a later healthy loader can commit' do
      result = described_class.discover(
        specifications: [
          spec('broken', loader: 'broken/stream_weaver'),
          spec('healthy', loader: 'healthy/stream_weaver')
        ],
        requireer: lambda { |loader|
          if loader == 'broken/stream_weaver'
            described_class.register(:partial_extension)
            raise SyntaxError, 'invalid extension loader'
          end

          described_class.register(:healthy_extension)
        }
      )

      expect(result.failures.map(&:loader)).to eq(['broken/stream_weaver'])
      expect(result.failures.first.error).to be_a(SyntaxError)
      expect(result.loaded.map(&:loader)).to eq(['healthy/stream_weaver'])
      expect(described_class).not_to be_registered(:partial_extension)
      expect(described_class).to be_registered(:healthy_extension)
    end

    it 'raises an actionable error when two loaders register the same extension ID' do
      registrations = 0

      expect do
        described_class.discover(
          specifications: [
            spec('alpha', loader: 'alpha/stream_weaver'),
            spec('beta', loader: 'beta/stream_weaver')
          ],
          requireer: lambda { |_loader|
            registrations += 1
            described_class.register(:diagram_intent)
          }
        )
      end.to raise_error(
        StreamWeaver::Extensions::DuplicateRegistrationError,
        /diagram_intent.*alpha\/stream_weaver.*beta\/stream_weaver/i
      )

      expect(registrations).to eq(2)
      expect(described_class).to be_registered(:diagram_intent)
    end

    it 'detects duplicate IDs registered within one loader and rolls back its stage' do
      expect do
        described_class.discover(
          specifications: [spec('alpha', loader: 'alpha/stream_weaver')],
          requireer: lambda { |_loader|
            described_class.register(:diagram_intent)
            described_class.register(:diagram_intent)
          }
        )
      end.to raise_error(StreamWeaver::Extensions::DuplicateRegistrationError, /diagram_intent/)

      expect(described_class).not_to be_registered(:diagram_intent)
    end

    it 'reports a broken loader while healthy loaders and built-in University courses remain available' do
      result = described_class.discover(
        specifications: [
          spec('broken', loader: 'broken/stream_weaver'),
          spec('healthy', loader: 'healthy/stream_weaver')
        ],
        requireer: lambda { |loader|
          raise LoadError, 'missing optional dependency' if loader == 'broken/stream_weaver'

          described_class.register(:healthy_extension)
        }
      )

      expect(result.failures.map(&:loader)).to eq(['broken/stream_weaver'])
      expect(result.failures.first.error).to be_a(LoadError)
      expect(result.loaded.map(&:loader)).to eq(['healthy/stream_weaver'])
      expect(described_class).to be_registered(:healthy_extension)

      require 'stream_weaver/university/course'
      expect(StreamWeaver::University::Course::GETTING_STARTED_STEPS).not_to be_empty
    end
  end

  describe '.register' do
    it 'records frozen extension records through the public StreamWeaver API' do
      registration = StreamWeaver.register_extension(:diagram_intent)

      expect(described_class.registered?(:diagram_intent)).to be(true)
      expect(registration).to be_frozen
      expect(described_class.all.first).to be_frozen
      expect { registration.id = 'changed' }.to raise_error(FrozenError)
      expect { registration.id << '-changed' }.to raise_error(FrozenError)
      expect { registration.source << '-changed' }.to raise_error(FrozenError)
      expect(described_class.all.first.id).to eq('diagram_intent')
    end

    it 'accepts only nonblank String or Symbol IDs' do
      [nil, 42, '', '   '].each do |id|
        expect { described_class.register(id) }
          .to raise_error(StreamWeaver::Extensions::InvalidExtensionIdError)
      end

      expect { described_class.register('diagram_intent') }.not_to raise_error
      expect { described_class.register(:second_extension) }.not_to raise_error
    end
  end

  describe 'top-level discovery' do
    it 'caches a modular loader failure so repeated discovery has no ghost registration or false success' do
      Dir.mktmpdir('stream-weaver-extension-spec') do |dir|
        FileUtils.mkdir_p(File.join(dir, 'modular_extension'))
        File.write(File.join(dir, 'modular_extension.rb'), <<~RUBY)
          File.open(#{File.join(dir, 'attempts.log').inspect}, 'a') { |file| file.puts('attempt') }
          require 'modular_extension/registration'
          raise LoadError, 'missing optional dependency'
        RUBY
        File.write(File.join(dir, 'modular_extension', 'registration.rb'), <<~RUBY)
          StreamWeaver.register_extension(:nested_extension)
        RUBY

        script = <<~RUBY
          $LOAD_PATH.unshift(#{dir.inspect})
          require 'stream_weaver'
          specification = Struct.new(:name, :metadata, keyword_init: true).new(
            name: 'broken',
            metadata: { 'stream_weaver.extensions.v1' => 'modular_extension' }
          )
          Gem::Specification.singleton_class.define_method(:each) { [specification] }
          first_result = StreamWeaver.discover_extensions
          second_result = StreamWeaver.discover_extensions
          abort 'missing failure' unless first_result.failures.map(&:loader) == ['modular_extension']
          abort 'false success' unless second_result.loaded.empty?
          abort 'failure was not replayed' unless second_result.failures.first.equal?(first_result.failures.first)
          abort 'nested registration survived' if StreamWeaver::Extensions.registered?(:nested_extension)
          abort 'loader was retried' unless File.readlines(#{File.join(dir, 'attempts.log').inspect}).length == 1
          require 'stream_weaver/university/course'
          abort 'built-in course missing' if StreamWeaver::University::Course::GETTING_STARTED_STEPS.empty?
          puts 'cached modular failure keeps University loadable'
        RUBY

        stdout, stderr, status = Open3.capture3(
          RbConfig.ruby,
          '-I', File.expand_path('../lib', __dir__),
          '-e', script
        )

        expect(status).to be_success, stderr
        expect(stdout).to include('cached modular failure keeps University loadable')
      end
    end
  end
end
