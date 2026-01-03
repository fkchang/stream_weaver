# frozen_string_literal: true

require_relative "lib/stream_weaver/version"

Gem::Specification.new do |spec|
  spec.name = "stream_weaver"
  spec.version = StreamWeaver::VERSION
  spec.authors = ["Forrest Chang"]
  spec.email = ["fkc_email-ruby@yahoo.com"]

  spec.summary = "Declarative Ruby DSL for building interactive web UIs with minimal token overhead"
  spec.description = "StreamWeaver enables GenAI agents and developers to rapidly build interactive web UIs using a declarative Ruby DSL. Features single-file execution, automatic state management, and agentic mode for AI-driven workflows."
  spec.homepage = "https://github.com/fkchang/stream_weaver"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/fkchang/stream_weaver"
  spec.metadata["changelog_uri"] = "https://github.com/fkchang/stream_weaver/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "sinatra", "~> 4.0"
  spec.add_dependency "phlex", "~> 2.0"
  spec.add_dependency "puma", "~> 6.4"
  spec.add_dependency "rackup", "~> 2.1"
  spec.add_dependency "kramdown", "~> 2.4"
  spec.add_dependency "kramdown-parser-gfm", "~> 1.1"
  spec.add_dependency "ostruct"  # Explicit dep for Ruby 3.5+ compatibility

  # Development dependencies
  spec.add_development_dependency "rack-test", "~> 2.1"
  spec.add_development_dependency "yard", "~> 0.9"
  spec.add_development_dependency "simplecov", "~> 0.22"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
