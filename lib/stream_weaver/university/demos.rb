# frozen_string_literal: true

module StreamWeaver
  module University
    # The canned artifacts every Getting Started step demonstrates.
    #
    # Round-5 UAT (2026-09-03) took ~5 minutes to reach first paint because
    # each worker session *composed* its demo live, and one of them went
    # looking for the source repo to do it. Both are now designed out: every
    # demo ships inside the gem as a finished, runnable file, so the worker's
    # job is to RUN it and NARRATE it -- never to invent it, and never to
    # need a checkout.
    #
    # `streamweaver university-demo <name>` prints the absolute path of one
    # of these inside the installed gem, which is what the course prompts
    # interpolate:
    #
    #   ruby "$(streamweaver university-demo dashboard)" dashboard
    #
    # Names are normalized (`decision-form` and `decision_form` are the same
    # demo) so a prompt, a spec and a human can each spell it the way that
    # reads best where they are.
    module Demos
      ROOT = File.expand_path('demos', __dir__)

      # name => path, relative to this file's directory. `doc` deliberately
      # points at the growing-doc script that already shipped for step 4
      # rather than a second copy of it -- one artifact, one place it can
      # rot.
      PATHS = {
        'dashboard' => File.join(ROOT, 'dashboard.rb'),
        'counter' => File.join(ROOT, 'counter.rb'),
        'decision-form' => File.join(ROOT, 'decision_form.rb'),
        'doc' => File.expand_path('scripts/growing_doc.rb', __dir__)
      }.freeze

      NAMES = PATHS.keys.freeze

      # `decision_form`, `decision-form` and `DECISION FORM` all resolve.
      def self.normalize(name)
        name.to_s.strip.downcase.tr('_ ', '--')
      end

      # @return [String, nil] absolute path, or nil for an unknown name
      def self.path(name)
        PATHS[normalize(name)]
      end
    end
  end
end
