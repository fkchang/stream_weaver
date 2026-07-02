# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in stream_weaver.gemspec
gemspec

# Optional iTerm2 split-pane integration (https://rubygems.org/gems/iterm2_ruby).
# Not a runtime dependency of the stream_weaver gem — end users opt in with
# `gem install iterm2_ruby`; StreamWeaver::ITerm falls back to the system browser.
# For local gem development: bundle config local.iterm2_ruby ~/work/iterm2_ruby
gem "iterm2_ruby", "~> 0.2"

gem "rake", "~> 13.0"

gem "rspec", "~> 3.0"

group :development do
  gem "opal", "~> 1.8"
end
