# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'
require_relative 'doc_store'
require_relative '../org/writer'

module StreamWeaver
  module Canvas
    # Publishes a canvas doc to a secret GitHub gist via the `gh` CLI.
    #
    # This is the only place in StreamWeaver that shells out to `gh` and the
    # only place that writes to an external, user-visible URL -- a coworker
    # opens the link this returns, so a bug here ships wrong content to a
    # real person rather than to a file the author can quietly fix.
    #
    # Both files go up in ONE api call: the rendered `.org` (what GitHub
    # renders as a formatted doc -- the reason for sharing at all) and the
    # re-runnable `.rb` DSL source (the source of truth). One save is
    # therefore exactly one gist revision, which is what makes
    # `<gist_url>/revisions` a meaningful timeline instead of a stutter of
    # half-updates. `gh gist create`/`gh gist edit` were rejected for this:
    # neither puts two files into a single call cleanly across the
    # create-vs-update split, and neither gives direct control over the JSON
    # payload.
    #
    # Visibility: secret, always. `public` is never sent -- not on create
    # (gh's own API default is secret, so omitting the key is the same as
    # asking for secret, with one less thing to get backwards) and never on
    # update, where GitHub silently ignores it because gist visibility is
    # immutable after creation. Sending a key that is either redundant or
    # ignored is a landmine for whoever reads this next.
    module GistPublisher
      # Seconds to wait on one `gh api` round trip. The caller is a Sinatra
      # request thread serving the canvas's Save-as-doc dialog; without this,
      # a stalled TLS handshake against api.github.com hangs that thread with
      # the user staring at a spinner. 20s is generous for a two-file POST and
      # still short enough to fail visibly.
      #
      # Timeout.timeout unblocks the CALLER, not the child: a `gh` that is
      # truly wedged may outlive the request by a few seconds before its own
      # network layer gives up. That is acceptable -- it holds no lock and
      # writes nothing of ours -- and is the reason this is a timeout rather
      # than a process kill.
      TIMEOUT_SECONDS = 20

      # Gist ids are hex strings. Anything else in `existing_id` would be
      # interpolated into the API path (`/gists/<id>`), where a `..` segment
      # would silently retarget the request at a different endpoint. argv is
      # already shell-safe, so this is not about shell injection -- it is
      # about not letting a corrupted store entry aim a PATCH somewhere
      # unintended.
      VALID_GIST_ID = /\A[A-Za-z0-9]+\z/

      # Stderr shapes that mean "your credentials are the problem", as
      # opposed to any other API failure. gh's own wording here is
      # famously unhelpful out of context ("Bad credentials (HTTP 401)"
      # tells a canvas user nothing), so these get rewritten into copy that
      # names the actual fix. Deliberately does NOT match a bare HTTP 403 --
      # that is also what rate limiting and org policy return, and mislabeling
      # those as an auth problem sends the user down the wrong path.
      AUTH_FAILURE_RE = /
        HTTP\s+401
        | bad\s+credentials
        | gh\s+auth\s+login
        | GH_TOKEN
        | not\s+accessible\s+by\s+personal\s+access\s+token
        | \bscope[s]?\b
        | SAML
      /xi

      # A deleted-upstream gist. Only meaningful on an update -- see #publish.
      NOT_FOUND_RE = /HTTP\s+404|\bnot\s+found\b/i

      AUTH_HELP = 'GitHub CLI could not authenticate. Run `gh auth login` and make sure the ' \
                  'token has the `gist` scope.'

      module_function

      # Renders `dsl` to both formats and publishes them as one gist.
      #
      # Returns a plain hash rather than raising, because every caller is an
      # HTTP handler that has to turn the outcome into a JSON body either way:
      #
      #   success: { ok: true, id:, url:, revisions:, action: "create"|"update",
      #              coverage: {...} }
      #   failure: { ok: false, error: "<message fit to show a user>" }
      #
      # On the stale-id recovery path the success hash also carries
      # `forget_stale_id: "<old id>"` -- the caller's cue to drop that id from
      # GistStore so the next save updates the new gist instead of chasing the
      # deleted one again.
      #
      # ArgumentError from an invalid doc name is deliberately NOT caught: it
      # is a 422 (the user typed a bad name), not a 502 (the publish failed),
      # and the existing save-doc handlers already map ArgumentError that way.
      # Swallowing it here into `ok: false` would flatten that distinction.
      def publish(name:, dsl:, theme: nil, layout: nil, existing_id: nil)
        base = base_name(name)

        writer = StreamWeaver::Org::Writer.new(dsl)
        org_text = writer.call
        coverage = writer.coverage
        rb_text = DocStore.dsl_with_metadata(dsl, theme: theme, layout: layout)

        payload = build_payload(base, org_text, rb_text)

        if existing_id
          unless existing_id.to_s.match?(VALID_GIST_ID)
            return { ok: false, error: "invalid gist id: #{existing_id.inspect}" }
          end

          out, err, status = gh_api('PATCH', "/gists/#{existing_id}", payload)
          return success(out, 'update', coverage) if status.success?

          # A 404 here means the gist was deleted on github.com since we last
          # recorded it. Publishing is still the thing the user asked for, so
          # mint a fresh gist rather than failing with a message about an id
          # they never saw and cannot act on. Only ever done for an update: a
          # 404 from a create is a real API problem, and retrying it would
          # just double the failure.
          return gh_error(err, status) unless err.to_s.match?(NOT_FOUND_RE)

          result = create(payload, coverage)
          return result unless result[:ok]

          return result.merge(forget_stale_id: existing_id)
        end

        create(payload, coverage)
      rescue Timeout::Error
        { ok: false, error: "gh timed out after #{TIMEOUT_SECONDS}s talking to GitHub" }
      end

      # Cheap presence check: is the `gh` binary on PATH at all?
      #
      # Deliberately NOT an auth check. `gh auth status` costs a network round
      # trip, and this is called on every canvas render to decide whether the
      # Gist radio is enabled -- putting a network call there would make the
      # dialog's responsiveness depend on GitHub being up. Auth problems
      # surface at publish time instead, where #publish already rewrites them
      # into actionable copy (see AUTH_HELP).
      #
      # Memoized: gh does not appear or vanish mid-process, and the widget
      # re-renders often enough that respawning a process per render would be
      # visible.
      def gh_available?
        return @gh_available unless @gh_available.nil?

        # system returns nil (not false) when the binary is missing, and the
        # caller renders this straight into a JSON/HTML attribute -- coerce so
        # the answer is always a real boolean.
        @gh_available = system('gh', '--version', out: File::NULL, err: File::NULL) ? true : false
      end

      def create(payload, coverage)
        out, err, status = gh_api('POST', '/gists', payload)
        return gh_error(err, status) unless status.success?

        success(out, 'create', coverage)
      end
      private_class_method :create

      # One `gh api` round trip. Array argv, never a shell string: the doc
      # name and gist id both reach this method from user input, and a shell
      # string is the one way to turn either into command execution.
      # `--input -` puts the JSON on stdin so no part of the payload ever
      # becomes an argument.
      def gh_api(verb, path, payload)
        Timeout.timeout(TIMEOUT_SECONDS) do
          Open3.capture3('gh', 'api', '-X', verb, path, '--input', '-', stdin_data: JSON.generate(payload))
        end
      end
      private_class_method :gh_api

      # Note the absence of a `public` key -- see the module comment. Both the
      # create and the update send this exact structure, which is what keeps
      # the two paths from drifting into sending different content.
      def build_payload(base, org_text, rb_text)
        {
          description: description_for(base, org_text),
          files: {
            "#{base}.org" => { content: org_text },
            "#{base}.rb" => { content: rb_text }
          }
        }
      end
      private_class_method :build_payload

      # The gist description is the line a coworker reads in a list of gists,
      # so the doc's own title beats the filename when there is one.
      # Org::Writer emits `#+TITLE:` only when the DSL declares a doc_header.
      def description_for(base, org_text)
        title = org_text[/^\#\+TITLE:\s*(.+)$/, 1]&.strip
        title && !title.empty? ? title : base
      end
      private_class_method :description_for

      def success(stdout, action, coverage)
        body = JSON.parse(stdout.to_s)
        # A zero-exit gh whose stdout is valid JSON but not a gist object
        # (`null`, a bare array) would otherwise NoMethodError on body['id']
        # and reach the Sinatra handler as a 500 stack trace. Nothing in gh
        # is known to do this -- the guard exists so an unexpected response
        # degrades to the same readable failure as an unparseable one.
        return { ok: false, error: "unexpected gh response: #{stdout.to_s[0, 200]}" } unless body.is_a?(Hash)

        {
          ok: true,
          id: body['id'],
          url: body['html_url'],
          # Every gist is a git repo and `history` is its commit list, so its
          # length is the revision count the widget shows next to the
          # /revisions link -- no extra call needed to compute it.
          revisions: Array(body['history']).length,
          action: action,
          coverage: coverage
        }
      rescue JSON::ParserError => e
        { ok: false, error: "could not parse gh response: #{e.message}" }
      end
      private_class_method :success

      def gh_error(stderr, status)
        message = stderr.to_s.strip
        return { ok: false, error: "#{AUTH_HELP} (gh said: #{message})" } if message.match?(AUTH_FAILURE_RE)
        return { ok: false, error: "gh exited #{status.exitstatus} with no output" } if message.empty?

        { ok: false, error: message }
      end
      private_class_method :gh_error

      # DocStore.normalize_name is the project's single definition of a valid
      # doc name (allowlist + explicit '..' and null-byte rejection) and it is
      # what the file-writing save routes already validate against. Reusing it
      # keeps a name that is legal for a gist identical to one that is legal
      # for a file, so the two Save-as-doc destinations can never disagree
      # about what the user typed.
      #
      # It is `private_class_method` on DocStore (it has no external caller
      # today), hence the `send`. Making it public is the better long-term
      # fix, but doc_store.rb is out of this story's scope -- flagged for
      # whoever next touches that file.
      #
      # normalize_name returns a name WITH its extension; a gist needs the
      # bare stem, because the publisher appends both extensions itself.
      def base_name(name)
        DocStore.send(:normalize_name, name).sub(/\.(rb|org)\z/, '')
      end
      private_class_method :base_name
    end
  end
end
