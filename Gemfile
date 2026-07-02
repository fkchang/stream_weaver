# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in stream_weaver.gemspec
gemspec

# Optional iTerm2 split-pane integration — loaded from local path when present
# (unpublished gem). StreamWeaver::ITerm falls back to the system browser without it.
iterm2_ruby_path = File.expand_path("~/work/iterm2_ruby")
gem "iterm2_ruby", path: iterm2_ruby_path if File.directory?(iterm2_ruby_path)

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

group :development do
  gem "opal", "~> 1.8"
end
