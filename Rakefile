# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

desc "Run the manual Phase-1 dispatch benchmark"
task :bench do
  ruby File.expand_path("bench/run.rb", __dir__)
end

task default: :spec
