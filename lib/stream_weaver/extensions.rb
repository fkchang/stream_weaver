# frozen_string_literal: true

module StreamWeaver
  # Discovers and records extensions contributed by installed gems.
  #
  # An extension gem opts in through its gemspec:
  #
  #   spec.metadata['stream_weaver.extensions.v1'] = 'my_gem/stream_weaver'
  #
  # Its loader then gives its contribution a stable identity:
  #
  #   StreamWeaver.register_extension(:my_gem)
  #
  # The versioned metadata key is deliberately the only discovery mechanism.
  # Scanning every file on the load path would make unrelated gems executable.
  # Discovery caches each loader's first result for the life of the process.
  # Restart after correcting a broken installed extension so Ruby reloads its
  # full loader tree from a clean $LOADED_FEATURES state.
  module Extensions
    METADATA_KEY = 'stream_weaver.extensions.v1'

    Extension = Struct.new(:id, :source, :course_provider, keyword_init: true)
    Loader = Struct.new(:gem_name, :loader, keyword_init: true)
    Failure = Struct.new(:gem_name, :loader, :error, keyword_init: true)
    Discovery = Struct.new(:loaded, :failures, keyword_init: true)

    class DuplicateRegistrationError < StreamWeaver::Error; end
    class InvalidExtensionIdError < StreamWeaver::Error; end

    @extensions = {}
    @loader_results = {}

    class << self
      # Requires metadata-declared extension loaders once per process, ordered
      # by gem name. Both successful and failed results are cached so a broken
      # modular loader cannot become a false success on a later require.
      # Restart the process after correcting an installed extension.
      #
      # `specifications`, `loaded_specs`, `resolver`, and `requireer` are
      # injectable so callers can verify extension behavior without changing
      # the process-wide RubyGems state.
      def discover(
        specifications: Gem::Specification.each,
        loaded_specs: Gem.loaded_specs,
        resolver: nil,
        requireer: Kernel.method(:require)
      )
        loaded = []
        failures = []

        metadata_loaders(
          specifications,
          loaded_specs: loaded_specs,
          resolver: resolver
        ).each do |specification, gem_name, loader|
          key = [gem_name, loader].freeze
          if (cached_result = @loader_results[key])
            append_cached_result(cached_result, loaded, failures)
            next
          end

          previous_source = @current_source
          previous_stage = @staged_extensions
          @current_source = immutable_string("#{gem_name} (#{loader})")
          @staged_extensions = {}

          begin
            activate_specification!(specification)
            requireer.call(loader)
            commit_staged_extensions!
            result = Loader.new(gem_name: gem_name, loader: loader).freeze
            @loader_results[key] = result
            loaded << result
          rescue DuplicateRegistrationError => error
            @loader_results[key] = error
            raise
          rescue LoadError, SyntaxError, StandardError => error
            result = Failure.new(
              gem_name: gem_name,
              loader: loader,
              error: error
            ).freeze
            @loader_results[key] = result
            failures << result
          ensure
            @current_source = previous_source
            @staged_extensions = previous_stage
          end
        end

        Discovery.new(loaded: loaded.freeze, failures: failures.freeze).freeze
      end

      # Registers an extension identity from a loader. IDs are global because
      # later extension points need one unambiguous owner for each provider.
      def register(id, course_provider: nil)
        normalized_id = normalize_id(id)
        source = immutable_string(@current_source || 'application')
        existing = @extensions[normalized_id] || @staged_extensions&.fetch(normalized_id, nil)

        if existing
          raise DuplicateRegistrationError,
                "Extension ID #{normalized_id.inspect} is already registered by #{existing.source}; " \
                "#{source} cannot register it again. Choose a unique extension ID."
        end

        registrations = @staged_extensions || @extensions
        registrations[normalized_id] = Extension.new(
          id: normalized_id,
          source: source,
          course_provider: course_provider
        ).freeze
      end

      def registered?(id)
        return false unless valid_id?(id)

        @extensions.key?(id.to_s)
      end

      def all
        @extensions.values.freeze
      end

      # Removes discovery and registration state. Intended for test isolation.
      def reset!
        @extensions.clear
        @loader_results.clear
        @current_source = nil
        @staged_extensions = nil
      end

      private

      def metadata_loaders(specifications, loaded_specs:, resolver:)
        specifications.group_by(&:name).filter_map do |gem_name, candidates|
          specification = selected_specification(
            gem_name,
            candidates,
            loaded_specs: loaded_specs,
            resolver: resolver
          )
          loader = specification.metadata&.fetch(METADATA_KEY, nil)
          next unless loader.is_a?(String) && !loader.empty?

          [specification, immutable_string(specification.name), immutable_string(loader)]
        end.sort_by { |_specification, gem_name, loader| [gem_name, loader] }
      end

      # A gem can be installed at multiple versions. Requiring a loader from
      # one version while RubyGems has activated another creates an accidental
      # mixed dependency tree, so select exactly one specification first.
      def selected_specification(gem_name, candidates, loaded_specs:, resolver:)
        active = loaded_specs[gem_name]
        return active if active && candidates.any? { |candidate| same_specification?(candidate, active) }

        resolved = resolver ? resolver.call(gem_name) : resolve_installed_specification(gem_name)
        return resolved if resolved && candidates.any? { |candidate| same_specification?(candidate, resolved) }

        candidates.max_by { |candidate| [specification_version(candidate), specification_identity(candidate)] }
      end

      def resolve_installed_specification(gem_name)
        Gem::Specification.find_by_name(gem_name)
      rescue Gem::LoadError
        nil
      end

      def same_specification?(left, right)
        left.equal?(right) || specification_identity(left) == specification_identity(right)
      end

      def specification_version(specification)
        return specification.version if specification.respond_to?(:version)

        Gem::Version.new('0')
      end

      def specification_identity(specification)
        return specification.full_name.to_s if specification.respond_to?(:full_name)

        specification.name.to_s
      end

      # Gem::Specification.each enumerates installed gems, including gems Ruby
      # has not activated yet. Activating the contributing gem first puts its
      # lib directory on the require path before Zeitwerk delegates the loader
      # to Kernel#require. Test fixtures need not emulate RubyGems activation.
      def activate_specification!(specification)
        specification.activate if specification.respond_to?(:activate)
      end

      def commit_staged_extensions!
        @extensions.merge!(@staged_extensions)
      end

      def append_cached_result(result, loaded, failures)
        case result
        when Loader
          loaded << result
        when Failure
          failures << result
        else
          raise result
        end
      end

      def normalize_id(id)
        unless valid_id?(id)
          raise InvalidExtensionIdError,
                'Extension ID must be a nonblank String or Symbol.'
        end

        immutable_string(id)
      end

      def valid_id?(id)
        (id.is_a?(String) || id.is_a?(Symbol)) && !id.to_s.strip.empty?
      end

      def immutable_string(value)
        value.to_s.dup.freeze
      end
    end
  end

  class << self
    def discover_extensions
      Extensions.discover
    end

    def register_extension(id, course_provider: nil)
      Extensions.register(id, course_provider: course_provider)
    end
  end
end
