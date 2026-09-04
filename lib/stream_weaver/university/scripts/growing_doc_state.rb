# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module StreamWeaver
  module University
    module Scripts
      # growing_doc.rb's picker/--extend memory, persisted to disk so a
      # second invocation for the same session rebuilds the SAME doc
      # instead of clobbering it.
      #
      # Round-7 UAT: a worker re-ran `--picker` without re-passing
      # `--extend=tradeoffs`, and the doc lost the section it had already
      # added -- the picker rebuild had no memory of what came before. No
      # agent memory should be required for this to work correctly: every
      # invocation now rebuilds base + ALL persisted keys on its own.
      #
      # Split out of growing_doc.rb itself (rather than a constant there)
      # because that file executes itself the moment it's loaded --
      # `StreamWeaver::University::Scripts::GrowingDoc.run!` at its own
      # bottom, so `ruby growing_doc.rb <session>` works with no wrapper --
      # which makes plain `require`ing it unsafe for anything that only
      # wants to touch its state file, like `university-reset`.
      module GrowingDocState
        # A directory, not a fixed filename -- STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR
        # overrides it (specs; a second isolated University instance), same
        # shape as Progress's own STREAMWEAVER_UNIVERSITY_PROGRESS override,
        # but per-session since more than one growing doc can exist.
        DEFAULT_DIR = '~/.streamweaver/university'

        def self.dir
          ENV['STREAMWEAVER_UNIVERSITY_DOC_STATE_DIR'] || File.expand_path(DEFAULT_DIR)
        end

        # e.g. session "doc-demo" -> ".../doc-demo_state.yml".
        def self.path(session_name)
          File.join(dir, "#{session_name}_state.yml")
        end

        def self.load(session_name)
          read(session_name)['extend_keys'] || []
        end

        def self.save(session_name, keys)
          write(session_name, read(session_name).merge('extend_keys' => keys))
        end

        # A worker-authored, free-text section (round-8 UAT: a picked
        # EXTENSIONS key already survives a later rebuild via extend_keys
        # above; a hand-written section had nowhere to persist, so the next
        # --picker round silently clobbered it back out -- a live run lost a
        # user's own Star Wars chart section exactly this way). Stored as
        # `{key => dsl}` so a rebuild can replay every custom section applied
        # so far, the same "everything so far, every time" contract
        # extend_keys already keeps.
        def self.load_custom(session_name)
          read(session_name)['custom_sections'] || {}
        end

        def self.save_custom(session_name, key, dsl)
          data = read(session_name)
          customs = (data['custom_sections'] || {}).merge(key => dsl)
          write(session_name, data.merge('custom_sections' => customs))
        end

        def self.clear(session_name)
          FileUtils.rm_f(path(session_name))
        end

        def self.read(session_name)
          file = path(session_name)
          return {} unless File.exist?(file)

          loaded = YAML.safe_load(File.read(file))
          loaded.is_a?(Hash) ? loaded : {}
        rescue Psych::SyntaxError
          {}
        end
        private_class_method :read

        def self.write(session_name, data)
          file = path(session_name)
          FileUtils.mkdir_p(File.dirname(file))
          File.write(file, YAML.dump(data))
        end
        private_class_method :write
      end
    end
  end
end
