# frozen_string_literal: true

require 'stream_weaver'
require 'stream_weaver/university/course'
require 'stream_weaver/university/demos'

module StreamWeaver
  module University
    # Combines StreamWeaver's built-in course with courses declared by
    # extension registrations. Provider execution and per-course progress are
    # deliberately outside this catalog: this layer only validates and lists.
    module CourseCatalog
      class InvalidProviderError < StreamWeaver::Error; end

      class << self
        # Returns built-ins first, then provider courses ordered by extension
        # ID. A provider's own course sequence stays meaningful and is kept.
        def build(extensions: Extensions.all)
          courses = [built_in_course]
          extensions.sort_by(&:id).each do |extension|
            provider = extension.course_provider
            next unless provider

            provider_courses(provider, extension.id).each do |raw_course|
              courses << normalize(raw_course, provider_id: extension.id)
            end
          end
          ensure_unique_ids!(courses)
          courses.freeze
        end

        private

        def built_in_course
          Course::Definition.new(
            id: 'getting-started'.freeze,
            title: 'Getting Started'.freeze,
            blurb: 'Learn StreamWeaver by running five real apps beside your terminal.'.freeze,
            steps: immutable_steps(Course::GETTING_STARTED_STEPS, 'stream_weaver'),
            demo_resolver: immutable_resolver(Demos.method(:path), 'stream_weaver'),
            provider_id: 'stream_weaver'.freeze
          ).freeze
        end

        def provider_courses(provider, provider_id)
          unless provider.respond_to?(:courses)
            invalid!(provider_id, :courses, 'must respond to #courses')
          end

          courses = provider.courses
          invalid!(provider_id, :courses, 'must be an Array') unless courses.is_a?(Array)

          courses
        rescue InvalidProviderError
          raise
        rescue StandardError => error
          invalid!(provider_id, :courses, "raised #{error.class}: #{error.message}")
        end

        def normalize(raw_course, provider_id:)
          invalid!(provider_id, :course, 'must be a Hash') unless raw_course.is_a?(Hash)
          raw = raw_course

          id = normalized_text(raw, :id, provider_id)
          title = normalized_text(raw, :title, provider_id)
          blurb = normalized_text(raw, :blurb, provider_id)
          steps = raw_value(raw, :steps)
          invalid!(provider_id, :steps, 'must be a nonempty Array') unless steps.is_a?(Array) && !steps.empty?

          demo_resolver = raw_value(raw, :demo_resolver)
          unless demo_resolver.respond_to?(:call)
            invalid!(provider_id, :demo_resolver, 'must respond to #call')
          end

          Course::Definition.new(
            id: id,
            title: title,
            blurb: blurb,
            steps: immutable_steps(steps, provider_id),
            demo_resolver: immutable_resolver(demo_resolver, provider_id),
            provider_id: provider_id.to_s.dup.freeze
          ).freeze
        end

        def ensure_unique_ids!(courses)
          seen = {}
          courses.each do |course|
            if seen.key?(course.id)
              invalid!(course.provider_id, :id, "duplicates #{course.id.inspect}")
            end
            seen[course.id] = true
          end
        end

        def normalized_text(raw, field, provider_id)
          value = raw_value(raw, field)
          unless (value.is_a?(String) || value.is_a?(Symbol)) && !value.to_s.strip.empty?
            invalid!(provider_id, field, 'must be a nonblank String or Symbol')
          end

          value.to_s.strip.dup.freeze
        end

        def raw_value(raw, field)
          raw.key?(field) ? raw[field] : raw[field.to_s]
        end

        def immutable_steps(value, provider_id)
          case value
          when Hash
            value.each_with_object({}) do |(key, entry), copy|
              copy[immutable_steps(key, provider_id)] = immutable_steps(entry, provider_id)
            end.freeze
          when Array
            value.map { |entry| immutable_steps(entry, provider_id) }.freeze
          when String
            value.dup.freeze
          when Symbol, Numeric, TrueClass, FalseClass, NilClass
            value
          else
            invalid!(provider_id, :steps, "contains unsupported #{value.class}")
          end
        end

        def immutable_resolver(resolver, provider_id)
          Course::Definition::Resolver.new(resolver)
        rescue TypeError, NoMethodError => error
          invalid!(provider_id, :demo_resolver, "could not be copied: #{error.message}")
        end

        def invalid!(provider_id, field, detail)
          raise InvalidProviderError, "Course provider #{provider_id.inspect} has invalid #{field.inspect}: #{detail}."
        end
      end
    end
  end
end
