# frozen_string_literal: true

require 'json'
require 'open3'

# Some emitted JavaScript is worth running rather than pattern-matching: the
# canvas form-state harvest and the deck's fetch handling are both behaviors no
# assertion about source text can pin. Include this in the describe block that
# needs node and the examples skip by name where node is absent.
#
# CI declares node (.github/workflows/ci.yml), so these always run where a
# regression has to be caught; a contributor without node gets a named skip
# rather than a failure about something they didn't break.
module NodeJS
  AVAILABLE = !!system('node', '--version', out: File::NULL, err: File::NULL)

  def self.included(base)
    base.before { skip 'node is not installed, so the emitted JS cannot be run' unless AVAILABLE }
  end

  # Runs the given JS fragments as one program and parses what it printed.
  #
  # The convention every caller shares: the fragments are a shim, the real
  # shipped JS, and a driver script that ends in one console.log(JSON...) --
  # stdout is the return channel, so a program that prints nothing parseable is
  # a failure worth raising on rather than a nil to chase later.
  def run_node_json(*parts)
    program = parts.join("\n")
    stdout, stderr, status = Open3.capture3('node', '-e', program)
    raise "node could not run this program: #{stderr}" unless status.success?

    JSON.parse(stdout)
  end
end
