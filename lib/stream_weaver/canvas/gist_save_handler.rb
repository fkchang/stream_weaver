# frozen_string_literal: true

require_relative 'gist_store'
require_relative 'gist_publisher'

module StreamWeaver
  module Canvas
    # scope == 'gist' branch of a save-doc route (share-to-gist epic),
    # shared between BridgeServer's live-canvas save and Reader's
    # history-snapshot promotion -- the only difference between the two
    # callers is whether there's a session's theme/layout to carry
    # (BridgeServer has one; Reader promotes a snapshot that never saw one,
    # same accepted limitation as this route's org/rb branches -- see
    # reader.rb's own comment on dsl_with_metadata).
    #
    # `include`d into both Sinatra::Base subclasses rather than left as two
    # hand-mirrored copies: it started that way (bridge-canvas-gist-endpoint,
    # then reader-gist-parity), and a second copy is exactly the point past
    # which "keep it duplicated" stops paying for itself -- `halt` below
    # resolves to whichever including Sinatra app calls it.
    module GistSaveHandler
      # base_name mirrors GistPublisher's own (private) base_name derivation
      # for a valid name: DocStore.normalize_name never rewrites characters,
      # it only validates and forces/strips the .rb/.org extension, so
      # stripping the extension here -- same regex the callers' own org
      # branches use -- lands on the identical string GistPublisher records
      # under. A non-String doc_name is passed through as-is (GistStore.lookup
      # coerces via #to_s, so this can only ever miss, not raise) so
      # GistPublisher.publish's own DocStore.normalize_name call is what
      # raises the ArgumentError, exactly like the callers' org/rb branches.
      def handle_gist_save(dsl, doc_name, theme: nil, layout: nil)
        rescue_save_errors do
          base_name = doc_name.is_a?(String) ? doc_name.sub(/\.(rb|org)\z/, '') : doc_name
          existing_id = GistStore.lookup(base_name)&.dig('id')

          result = GistPublisher.publish(
            name: doc_name,
            dsl: dsl,
            theme: theme,
            layout: layout,
            existing_id: existing_id
          )

          halt 502, { ok: false, error: result[:error] }.to_json unless result[:ok]

          response = {
            ok: true,
            gist_url: result[:url],
            gist_id: result[:id],
            revisions: result[:revisions],
            action: result[:action],
            coverage: result[:coverage]
          }

          # A GistStore.record failure must never fail an otherwise-successful
          # publish -- the gist is already live at result[:url] regardless of
          # whether we can remember it locally. Mirrors how DocStore.save
          # swallows a DocRoots.record failure (doc_store.rb:151) rather than
          # raising it back at the caller.
          begin
            GistStore.record(
              base_name, id: result[:id], url: result[:url], revisions: result[:revisions]
            )
          rescue StandardError => e
            response[:warning] = "gist saved, but recording it locally failed: #{e.message}"
          end

          # Stale-id recovery (see GistPublisher#publish): result[:forget_stale_id],
          # when present, is the OLD gist id that 404'd on PATCH -- there is
          # nothing further to clean up for it. GistStore is keyed by doc NAME,
          # not gist id, and GistStore.record above already overwrote this
          # doc's one entry with the freshly-minted id, so the stale id was
          # never left behind under any key to forget.
          response.to_json
        end
      end

      # Shared ArgumentError->422 / StandardError->500 mapping for the
      # org/rb/gist save-doc branches.
      def rescue_save_errors
        yield
      rescue ArgumentError => e
        halt 422, { ok: false, error: e.message }.to_json
      rescue StandardError => e
        halt 500, { ok: false, error: e.message }.to_json
      end
    end
  end
end
