# frozen_string_literal: true

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
end
