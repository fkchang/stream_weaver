# frozen_string_literal: true

require 'stringio'

# Scoped capture of the process-global IO streams, for specs that assert on
# what a CLI command printed. Every swap is restored in an `ensure`: the
# example under test is usually one that can raise, and a leaked StringIO on
# $stdin or $stderr silently changes what every LATER spec in the run sees.
module OutputHelper
  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def capture_stderr
    original = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original
  end

  def with_stdin(text)
    original = $stdin
    $stdin = StringIO.new(text)
    yield
  ensure
    $stdin = original
  end
end
