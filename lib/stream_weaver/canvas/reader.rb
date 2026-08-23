# frozen_string_literal: true

require 'cgi'
require 'json'
require 'socket'
require 'sinatra/base'
require 'stream_weaver/app'
require 'stream_weaver/views'
require 'stream_weaver/adapter/alpinejs'
require 'stream_weaver/canvas/doc_store'
require 'stream_weaver/canvas/doc_roots'
require 'stream_weaver/canvas/save_doc_widget'
require 'stream_weaver/page_shell'
require 'stream_weaver/export/html_exporter'
require 'stream_weaver/org/writer'
require 'stream_weaver/org/reader'

module StreamWeaver
  module Canvas
    class Reader < Sinatra::Base
      class NoFilesError < StandardError; end

      class FileList
        attr_reader :files, :history_roots, :labels

        # `labels` is {root_path => display_label} for multi-repo discovery
        # (stream_weaver-iugu). Optional and defaulted so the single-root and
        # history-root callers that predate it are untouched -- a directory
        # with no label falls back to its own basename, which is exactly what
        # the sidebar showed before labels existed.
        def self.build(args, history_roots: [], labels: {})
          files = args.flat_map do |arg|
            if File.directory?(arg)
              Dir.glob(File.join(arg, '*.{rb,org}')).sort
            elsif File.exist?(arg) && arg.end_with?('.rb', '.org')
              [File.expand_path(arg)]
            else
              []
            end
          end.uniq

          raise NoFilesError, "No .rb or .org files found in: #{args.join(', ')}" if files.empty?

          new(files, args: args, history_roots: history_roots, labels: labels)
        end

        # A list with no files, still remembering where it was looking.
        # Deliberately not reachable from .build (which raises NoFilesError
        # instead, so `canvas-read nosuchdir` still fails loudly at boot) --
        # this is only for a list that HAD files and lost its last one while
        # the reader was running (stream_weaver-uvaj).
        def self.empty(args, history_roots: [], labels: {})
          new([], args: args, history_roots: history_roots, labels: labels)
        end

        def initialize(files, args:, history_roots: [], labels: {})
          @files = files
          @args = args
          @history_roots = history_roots.map { |p| File.expand_path(p) }
          @labels = labels.each_with_object({}) { |(root, label), out| out[File.expand_path(root)] = label }
          @dir_mtimes = snapshot_dir_mtimes
        end

        # True when a source directory's mtime has moved since this list was
        # built (stream_weaver-gnj8) -- a directory's own mtime bumps when
        # an entry is added or removed inside it (a Save-as-doc write, a git
        # pull, a direct edit from any process), which is the only kind of
        # change that affects what FILES are in this list. An existing
        # file's own content changing does NOT bump its directory's mtime
        # and doesn't need to: GET / already re-reads file content fresh on
        # every request regardless of this cache, so only the *set* of
        # files can ever go stale here.
        def stale?
          @dir_mtimes.any? { |dir, snapshot| current_mtime(dir) != snapshot }
        end

        # Rebuilds from the same source args if stale, otherwise returns
        # self unchanged -- the common (nothing changed) case costs one
        # stat() per source directory and nothing else.
        def rebuild_if_stale
          return self unless stale?

          self.class.build(@args, history_roots: @history_roots, labels: @labels)
        rescue NoFilesError
          # Two very different situations land here and they want opposite
          # answers:
          #
          # * Every source directory VANISHED (deleted, unmounted, or -- in
          #   specs -- a Dir.mktmpdir block that already exited). Keep
          #   serving the last-known list rather than raising: a stale list
          #   is still useful navigation, a crashed request is not, and the
          #   paths may well come back. Matches browse_entries/
          #   resolve_browse_dir's existing philosophy elsewhere in this
          #   class -- filesystem drift degrades gracefully, never 500s.
          # * The directories are all still THERE and simply hold no docs
          #   any more -- which is exactly what deleting the last one
          #   produces (stream_weaver-uvaj). Here the list really is empty,
          #   and answering with the stale one leaves the file you just
          #   deleted in the rail behind a link that 500s on File.read.
          if @args.any? { |arg| File.exist?(arg) }
            self.class.empty(@args, history_roots: @history_roots, labels: @labels)
          else
            self
          end
        end

        def groups
          @files.group_by { |f| File.dirname(f) }
        end

        def indexed_groups
          @indexed_groups ||= @files.each_with_index.group_by { |f, _| File.dirname(f) }
        end

        # True when dir is the same as a history root or sits underneath one.
        def history_dir?(dir)
          @history_roots.any? { |r| dir == r || dir.start_with?(r + '/') }
        end

        # Display name for a docs directory: its registered label when it has
        # one (the repo it belongs to), otherwise its own basename.
        def label_for(dir)
          @labels[dir] || @labels[File.expand_path(dir)] || File.basename(dir)
        end

        # Label for an arbitrary root path, compared canonically -- the host
        # repo's docs root arrives from Reader.repo_docs_root, which resolves
        # via Dir.pwd and can differ from the registered spelling by a
        # symlink (/tmp vs /private/tmp on macOS). nil when no group matches,
        # which is what tells the filter to fall back rather than select a
        # group that isn't there.
        def label_for_root(path)
          return nil unless path

          expanded = File.expand_path(path)
          return @labels[expanded] if @labels.key?(expanded)

          key = DocRoots.canonical(expanded)
          hit = @labels.keys.find { |k| DocRoots.canonical(k) == key }
          hit && @labels[hit]
        end

        # Sidebar splits: docs (explicit args) render above, history (auto-collected
        # snapshots from ~/.streamweaver/history/) renders below collapsed.
        #
        # `repo:` narrows to one label (stream_weaver-iugu). It filters which
        # GROUPS render, never the file indices inside them -- ?file=N stays a
        # position in the whole list, so a filtered sidebar and an unfiltered
        # one address the same files and no link changes meaning when the
        # filter does.
        def docs_groups(repo: nil)
          groups = indexed_groups.reject { |dir, _| history_dir?(dir) }
          return groups unless repo

          groups.select { |dir, _| label_for(dir) == repo }
        end

        # Labels of every docs group with at least one file, in sidebar order.
        def repo_labels
          indexed_groups.keys.reject { |dir| history_dir?(dir) }.map { |dir| label_for(dir) }.uniq
        end

        def history_groups
          indexed_groups.select { |dir, _| history_dir?(dir) }
        end

        # Array#[] wraps on negative indices and nil.to_i is 0 -- neither is a
        # valid file reference, so this refuses both centrally rather than
        # every caller re-deriving the same guard (and GET / not bothering to).
        def at(index)
          @files[index] if index.is_a?(Integer) && index >= 0
        end

        def size
          @files.size
        end

        private

        def snapshot_dir_mtimes
          @args.each_with_object({}) do |arg, snapshot|
            snapshot[arg] = current_mtime(arg) if File.directory?(arg)
          end
        end

        # A directory that vanished since boot reads as nil, which never
        # equals a real mtime -- stale? then forces a rebuild attempt
        # rather than silently trusting a cache that points at nothing.
        # If genuinely nothing is left, .build's own NoFilesError still
        # fires the way it always has.
        def current_mtime(dir)
          File.mtime(dir)
        rescue SystemCallError
          nil
        end
      end

      MERMAID_ZOOM_JS = File.read(File.expand_path('../assets/js/sw-mermaid-zoom.js', __dir__))
      private_constant :MERMAID_ZOOM_JS

      configure do
        set :views,   File.expand_path('../views/canvas', __dir__)
        set :bind,    '127.0.0.1'
        set :server,  :puma
        set :logging, false
      end

      # What Reader.render_doc hands the layout template: the rendered HTML
      # plus the theme/layout/CSS the DSL declared for itself, which the shell
      # needs for the <body> class and the user-CSS <style> tags.
      Doc = Struct.new(:html, :theme, :layout, :inline_stylesheets, keyword_init: true)

      class << self
        attr_reader :default_theme, :default_layout

        # Returns the configured FileList, rebuilding it first if it's gone
        # stale (stream_weaver-gnj8 -- see FileList#stale?). nil-safe: a
        # future Browse-only boot mode with no configured files at all
        # would leave @file_list nil, which has nothing to rebuild.
        # Concurrent requests both detecting staleness and both rebuilding
        # is possible under Puma's threaded server -- harmless (each
        # rebuild produces an equivalent, immutable FileList; worst case is
        # redundant work, never corruption), so not worth a mutex for a
        # single-user local dev tool.
        def file_list
          @file_list = @file_list.rebuild_if_stale if @file_list
          @file_list
        end

        def configure_files!(list)
          @file_list = list
        end

        # Fallback theme/layout for files that don't declare their own
        # (`canvas-read --theme=doc --layout=fluid`). Precedence is
        # DSL use_theme > CLI flag > :default/:fluid.
        def configure_defaults!(theme: nil, layout: nil)
          @default_theme  = theme&.to_sym
          @default_layout = layout&.to_sym
        end

        # render_doc and GET /export both need these; a single source of
        # truth is what makes "the download matches what's on screen" true
        # rather than aspirational -- two independent `|| :fluid`s could
        # silently drift.
        def fallback_theme
          default_theme || :default
        end

        def fallback_layout
          default_layout || :fluid
        end

        def find_available_port(start = 4800)
          port = start
          loop do
            TCPServer.new('127.0.0.1', port).close
            return port
          rescue Errno::EADDRINUSE
            port += 1
            raise "No available port found starting from #{start}" if port > start + 100
          end
        end

        # Absolute path of the current repo's docs root, or nil outside a
        # git repo. Same resolution DocStore.path itself would use for the
        # "in a repo" branch -- kept as a named shortcut (not stored state)
        # for the Browse view's quick-jump link (stream_weaver-rdh).
        def repo_docs_root
          root = StreamWeaver::Canvas::DocStore.git_root(Dir.pwd)
          root && File.join(root, StreamWeaver::Canvas::DocStore::DOCS_SUBPATH)
        end

        # The only two docs roots this process is allowed to delete from
        # (stream_weaver-uvaj), canonicalized. Both resolve from THIS
        # process's own state -- the repo canvas-read was launched in, and
        # the global store -- never from what an attaching client claims,
        # and never from the peer repos DocRoots surfaces for reading. A
        # peer repo's docs are readable here and permanently undeletable:
        # narrower blast radius wins over full reach (design doc, Delete).
        def deletable_roots
          [repo_docs_root, DocStore::DEFAULT_ROOT].compact.filter_map { |root| canonical_file(root) }
        end

        # Symlink- and `..`-resolved absolute path, or nil for anything that
        # doesn't resolve to something on disk. One helper for every
        # comparison below, so the delete guard and the "is this the file we
        # just deleted?" lookup can't drift apart on how they canonicalize.
        # expand_path first, for `~` (and its ArgumentError on `~nosuchuser`).
        def canonical_file(path)
          File.realpath(File.expand_path(path.to_s))
        rescue SystemCallError, ArgumentError, TypeError
          nil
        end

        # True when a sidebar group's directory is one of those two roots --
        # what decides whether its rows render a delete control at all. The
        # UI just stops you asking for something POST /delete-doc would
        # refuse anyway; the server-side check below is the actual boundary.
        def deletable_dir?(dir)
          real = canonical_file(dir)
          !real.nil? && deletable_roots.include?(real)
        end

        # The canonical absolute path when `raw` names a doc file sitting
        # DIRECTLY in one of the deletable roots; nil for anything else.
        #
        # The containment test is equality on the canonicalized direct
        # PARENT, not `start_with?` against the root. A prefix match would
        # happily accept a sibling directory whose name merely begins with
        # the root's (`..._canvas_evil/x.rb`), and would accept arbitrarily
        # nested subdirectories the sidebar never lists. realpath resolves
        # every `..` and symlink first, so neither a traversal
        # (`<root>/../../../etc/x.rb`) nor a symlink planted inside the root
        # pointing out of it survives the comparison -- the link resolves to
        # its target, whose parent is not the root.
        #
        # Deliberately NOT hardened against a symlink swapped in between
        # this check and the File.delete that follows: single-user local
        # tool, explicitly out of the threat model (design doc, Explicitly
        # declined).
        def deletable_path(raw)
          return nil unless raw.is_a?(String) && !raw.empty? && !raw.include?("\0")
          return nil unless raw.end_with?('.rb', '.org')

          real = canonical_file(raw)
          return nil unless real && File.file?(real)

          deletable_roots.include?(File.dirname(real)) ? real : nil
        end

        # Which `?file=N` to land on after a delete, read off the REBUILT
        # list (file_list re-globs itself once the directory mtime moves).
        # `deleted` is the removed file's index in the pre-delete list,
        # `current` the index that was open in the browser.
        #
        # Deleting the open doc keeps the same position, because the next
        # surviving doc slides into it -- clamped to the last index, which
        # is what "step back one" means when the deleted doc was last. A doc
        # deleted from ABOVE the open one shifts it down by one, so the same
        # file stays on screen instead of the rail silently jumping. nil
        # means nothing is left to open.
        def index_after_delete(deleted, current)
          size = file_list&.size.to_i
          return nil if size.zero?

          current = nil unless current.is_a?(Integer) && current >= 0
          return 0 unless current

          adjusted = deleted && current > deleted ? current - 1 : current
          [adjusted, size - 1].min
        end

        # Which repo group the sidebar shows, from the `?repo=` param
        # (stream_weaver-iugu). Returns a label, or nil meaning "all."
        #
        # - `?repo=all` (or any label with no matching group) is the explicit
        #   clear. An unknown label falling back to "all" rather than 404ing
        #   is deliberate: a bookmarked filter whose repo has since been
        #   deleted should still show you your docs.
        # - No param at all defaults to the repo the reader process was
        #   launched from, so `cd myrepo && canvas-read` opens on myrepo's
        #   docs. Falls back to the global store, then to "all" -- launched
        #   from a repo with no docs of its own, showing everything beats
        #   showing an empty rail.
        def resolve_repo_filter(raw, list)
          return nil unless list

          value = raw.to_s
          return nil if value == 'all'
          return list.repo_labels.include?(value) ? value : nil unless value.empty?

          default_repo_filter(list)
        end

        def default_repo_filter(list)
          labels = list.repo_labels
          # The host repo has no label of its own to compare against -- it
          # arrives as a path -- so it's matched by path. The global store
          # is matched by its label instead, since that label is a constant
          # DocRoots assigns and is the same thing `?repo=` addresses.
          host = list.label_for_root(repo_docs_root)
          return host if host && labels.include?(host)

          DocRoots::GLOBAL_LABEL if labels.include?(DocRoots::GLOBAL_LABEL)
        end

        # {dirs:, files:} immediately under `dir` -- one level, not recursive
        # (Browse navigates by clicking in, not by a pre-walked tree). Dotfiles
        # excluded (matches normal file-browser expectations; a .git directory
        # in the listing is noise, never something you'd navigate into here).
        # Swallows ENOENT/EACCES rather than raising: a stale bookmark or a
        # permission-denied directory should render an empty listing, not a 500.
        def browse_entries(dir)
          entries = Dir.children(dir).reject { |e| e.start_with?('.') }.sort
          # partition, not two independent #select calls: a directory named
          # "bundle.rb" (rare, but real -- generator fixtures do this) would
          # otherwise satisfy both the dirs and files predicates and get
          # listed twice, the second listing a dead link (/open 404s on it).
          dirs, rest = entries.partition { |e| File.directory?(File.join(dir, e)) }
          { dirs: dirs, files: rest.select { |e| e.end_with?('.rb', '.org') } }
        rescue SystemCallError
          # Broader than Errno::ENOENT/EACCES alone: a TCC-protected macOS
          # directory (~/Library/Mail, ~/Documents without Full Disk Access)
          # raises Errno::EPERM, not EACCES, and $HOME -- Browse's own
          # default landing directory -- routinely contains one. A symlink
          # loop raises Errno::ELOOP. All of them mean the same thing here:
          # show an empty listing, not a 500.
          { dirs: [], files: [] }
        end

        # Expands and validates a Browse `dir` param, falling back to $HOME
        # for anything blank, relative-and-missing, or not actually a
        # directory -- Browse always has *somewhere* valid to show rather
        # than erroring on a stale/hand-edited query string. The rescue
        # covers what File.expand_path itself can raise on bad input
        # (?dir=~nosuchuser, a null byte, a non-String param from
        # ?dir[]=x) -- all real, reachable ways to reach this from a
        # browser address bar or a stale link, not just theoretical.
        def resolve_browse_dir(raw)
          expanded = raw && !raw.to_s.empty? && (File.expand_path(raw.to_s) rescue nil)
          expanded && File.directory?(expanded) ? expanded : Dir.home
        end
      end

      # 127.0.0.1-binding stops a remote client, but not a browser already
      # on this machine: any page open in any tab can issue a cross-origin
      # GET here with no CSRF token required (an <img src="http://127.0.0.1:
      # 4800/open?path=...">, a bare <a>, a form) -- same-origin policy
      # blocks that page from READING the response, not from sending the
      # request. That distinction didn't matter much when the worst case
      # was an unwanted render; it matters a great deal now that /open
      # (stream_weaver-rdh) *evaluates* the .rb file it opens.
      #
      # Two independent checks, because either alone has a gap:
      # - Host: blocks the common drive-by case outright. Beaten by DNS
      #   rebinding, where an attacker's domain re-resolves to 127.0.0.1
      #   mid-session, making the request genuinely same-origin by the time
      #   it arrives.
      # - Sec-Fetch-Site: set by the browser itself from the *page's own*
      #   origin, not spoofable by page JS, so it still reads "cross-site"
      #   after a rebind. Older browsers omit the header entirely; failing
      #   open on absence (rather than blocking) is deliberate -- this is a
      #   single-user local dev tool where the primary path is a modern
      #   browser navigating here directly, and false positives there would
      #   be worse than the residual risk from a browser old enough to omit
      #   Fetch Metadata.
      before do
        halt 403, 'Forbidden' unless %w[127.0.0.1 localhost].include?(request.host)

        site = request.env['HTTP_SEC_FETCH_SITE']
        halt 403, 'Forbidden' if site && !%w[same-origin none].include?(site)
      end

      get '/health' do
        'ok'
      end

      get '/' do
        return redirect '/?file=0' unless params.key?('file')

        index = params[:file].to_i
        list  = self.class.file_list
        path  = list&.at(index)
        # "Nothing left to open" is a real state now (stream_weaver-uvaj:
        # you just deleted the last doc), not a bad request -- answering a
        # successful delete with a 404 page would be a lie about what
        # happened. Renders the same no-doc-open placeholder a bare Browse
        # already uses.
        return render_no_doc(list) if path.nil? && list && list.size.zero?
        halt 404, 'File not found' unless path

        dsl = File.read(path)
        @doc             = Reader.render_doc(dsl, path: path)
        @file_list       = list
        @current_index   = index
        @current_file    = path
        # @repo_filter is the resolved label the sidebar renders; @repo_param
        # is the raw param, carried through every in-sidebar link so an
        # explicit filter survives navigation instead of snapping back to the
        # host-repo default on the next click.
        @repo_filter     = self.class.resolve_repo_filter(params[:repo], list)
        @repo_param      = params[:repo].to_s.empty? ? nil : params[:repo].to_s
        @mermaid_zoom_js = MERMAID_ZOOM_JS
        erb :reader_layout, layout: false
      end

      # Live filesystem browse (stream_weaver-rdh) -- the thing actually
      # missing before this: canvas-read already renders any file/dir handed
      # to it as a CLI arg, but once running, you're stuck with what you
      # started it with. No index, no registered locations: browsing IS the
      # discovery, computed fresh on every request. NOT the same trust
      # boundary as the CLI args this already accepts, despite first
      # appearances -- a CLI arg is the user naming a file once, with
      # intent; an HTTP GET is reachable from any tab in the user's
      # browser, and /open below evaluates what it opens. See the `before`
      # filter above for why that gap is actually closed.
      #
      # No `?file=N` here -- Browse's sidebar replaces the file-list view
      # entirely rather than adding to it, so there's no index into anything
      # to render disabled/enabled Prev/Next against. @current_index stays
      # unset, which the layout's nav block treats as "no file open."
      get '/browse' do
        set_browse_ivars(self.class.resolve_browse_dir(params[:dir]))
        @file_list       = self.class.file_list
        @mermaid_zoom_js = MERMAID_ZOOM_JS
        erb :reader_layout, layout: false
      end

      # Renders one file found via Browse, independent of the configured
      # FileList/docs_groups/history_groups -- this is what makes Browse not
      # need an index: viewing a browsed file was never routed through a
      # precomputed list to begin with. Sidebar stays in Browse mode (the
      # opened file's own directory), so browsing feels continuous rather
      # than dropping back to the original file list.
      get '/open' do
        path = File.expand_path(params[:path].to_s)
        halt 404, 'File not found' unless File.file?(path) && path.end_with?('.rb', '.org')

        dsl = begin
          File.read(path)
        rescue SystemCallError
          halt 404, 'File not found'
        end
        @doc             = Reader.render_doc(dsl, path: path)
        @current_file    = path
        set_browse_ivars(File.dirname(path))
        @file_list       = self.class.file_list
        @mermaid_zoom_js = MERMAID_ZOOM_JS
        erb :reader_layout, layout: false
      end

      # Download the currently-viewed file as a standalone HTML document.
      # Same ?file=N index convention as GET /, and the same theme/layout
      # fallbacks render_doc uses (fallback_theme/fallback_layout), so the
      # download matches what's on screen.
      #
      # Failures answer text/plain with a status, never a partial document:
      # a half-written .html landing in ~/Downloads looks like a success.
      # content_type is set to :text up front for exactly that reason --
      # halt'ing after a `content_type :html` would still serve the error
      # body as HTML. The export link itself must never carry a `download`
      # attribute, or the browser saves an error body as a mystery file
      # instead of showing it (see reader_layout.erb).
      # ?offline=1 inlines mermaid's own library instead of referencing its
      # CDN (stream_weaver-dnq), so a diagram renders in a viewer whose CSP
      # blocks external scripts entirely (SharePoint's HTML preview, etc.).
      # Needs network access at export time; a fetch failure there is a 502
      # (this server tried an upstream and it failed), distinct from the
      # 422s below for bad input.
      get '/export' do
        content_type :text
        path = self.class.file_list&.at(params[:file].to_i)
        halt 404, 'File not found' unless path

        html = begin
          StreamWeaver::Export::HtmlExporter.from_dsl_file(
            path,
            theme:  self.class.fallback_theme,
            layout: self.class.fallback_layout
          ).to_html(offline: params[:offline] == '1')
        rescue StreamWeaver::Export::InvalidDslError => e
          halt 422, "Export failed: #{e.message}"
        rescue StreamWeaver::Export::OfflineAssetError => e
          halt 502, "Export failed: #{e.message}"
        rescue ScriptError, StandardError => e
          # A DSL that fails to eval is bad input, not an exporter failure --
          # same 422 GET / gives the equivalent case (its red error box).
          halt 422, "Export failed: #{e.message}"
        end

        content_type :html
        headers['Content-Disposition'] =
          %(attachment; filename="#{StreamWeaver::Export::HtmlExporter.export_filename(path)}")
        html
      end

      # Promote a history snapshot to a persistent canvas doc (Tier 2).
      # Body: {"file": <integer-index>, "name": "<doc-name>", "format": "rb"|"org"}.
      # format defaults to "rb". Mirrors BridgeServer's /canvas/:name/save-doc
      # contract: 200 on success, 422 on bad index / bad name / bad format,
      # 404 when no list configured, 500 otherwise.
      post '/save-doc' do
        content_type :json
        list = self.class.file_list
        halt 404, { ok: false, error: 'No file list configured' }.to_json unless list

        body   = JSON.parse(request.body.read, symbolize_names: true) rescue {}
        index  = body[:file]
        name   = body[:name]
        format = body[:format] || 'rb'
        halt 422, { ok: false, error: "unrecognized format: #{format.inspect}" }.to_json unless %w[rb org].include?(format)
        # The Save-as-doc toggle (stream_weaver-j3b3). No source_dir is passed
        # to DocStore.save below -- unlike BridgeServer, the reader has no
        # live session to carry one, so "This repo" keeps resolving the same
        # way it always has: DocStore's own auto-detection off the reader
        # process's cwd (see reader_layout.erb's SaveDocWidget.render call).
        scope = body[:scope] == 'global' ? :global : :repo

        # FileList#at already refuses non-Integer/negative indices; File.exist?
        # covers the case an in-range index still points at a file that's
        # since been deleted out from under us.
        file_path = list.at(index)
        unless file_path && File.exist?(file_path)
          halt 422, { ok: false, error: "File index out of range: #{index.inspect}" }.to_json
        end

        # No DocStore.dsl_with_metadata call here, unlike BridgeServer's
        # save-doc route: this promotes a history snapshot, and snapshots are
        # written by `canvas-push` (CLI.record_push_history), which never sees
        # the bridge session's theme/layout. There is nothing to inject.
        # Snapshots whose DSL doesn't declare `use_theme` itself keep rendering
        # with canvas-read's default -- accepted limitation (stream_weaver-csf).
        dsl = File.read(file_path)
        begin
          if format == 'org'
            writer   = StreamWeaver::Org::Writer.new(dsl)
            org_text = writer.call
            # Strip any .rb/.org the user already typed before appending .org --
            # otherwise a name like "mydoc.org" round-trips to "mydoc.org.org"
            # (DocStore.normalize_name only strips ONE trailing extension, so
            # blindly appending here is not idempotent against an already-typed one).
            # Only strip when name is actually a String -- a non-String is
            # passed through as-is so DocStore.save's own type check rejects
            # it with the same ArgumentError the .rb path below already gets
            # for free, instead of silently coercing it via #to_s.
            org_name = name.is_a?(String) ? "#{name.sub(/\.(rb|org)\z/, '')}.org" : name
            saved_path = StreamWeaver::Canvas::DocStore.save(org_name, org_text, scope: scope)
            { ok: true, path: saved_path, coverage: writer.coverage }.to_json
          else
            saved_path = StreamWeaver::Canvas::DocStore.save(name, dsl, scope: scope)
            { ok: true, path: saved_path }.to_json
          end
        rescue ArgumentError => e
          halt 422, { ok: false, error: e.message }.to_json
        rescue StandardError => e
          halt 500, { ok: false, error: e.message }.to_json
        end
      end

      # Deletes one saved doc (stream_weaver-uvaj). Body:
      # {"path": "<absolute path>", "file": <currently-open index or null>}.
      #
      # Reader-only on purpose: BridgeServer has no doc inventory to delete
      # from. Plain File.delete, no git shelling -- the unstaged deletion
      # showing up in `git status` afterward is the intended outcome, and
      # committing it is the user's call, same as deleting in Finder.
      #
      # 403 (not 404) for a path outside the two deletable roots: the
      # request was understood and refused, and a 404 would leak whether the
      # file exists. Never reachable from Browse mode, which can point at
      # any directory on the machine -- arbitrary-path READ is a reviewed,
      # accepted risk there; arbitrary-path DELETE would not be.
      post '/delete-doc' do
        content_type :json
        body = begin
          JSON.parse(request.body.read, symbolize_names: true)
        rescue StandardError
          {}
        end

        path = self.class.deletable_path(body[:path])
        halt 403, { ok: false, error: 'Not a deletable doc path' }.to_json unless path

        # Resolved BEFORE the delete, while the file is still in the list:
        # this is the position the doc occupied, which is what tells the
        # client whether the open doc's index shifts.
        list    = self.class.file_list
        deleted = list&.files&.index { |f| self.class.canonical_file(f) == path }

        begin
          File.delete(path)
        rescue SystemCallError => e
          halt 500, { ok: false, error: e.message }.to_json
        end

        { ok: true, path: path, file: self.class.index_after_delete(deleted, body[:file]) }.to_json
      end

      # Evaluates `dsl` and returns a Doc carrying the rendered HTML plus the
      # theme/layout/inline CSS the DSL declared for itself -- the reader shell
      # needs all four, and render_dsl's HTML-only return threw the rest away
      # (stream_weaver-csf).
      #
      # Caveat: rendering goes through AppContentView, which does not evaluate
      # exclusive-layout render blocks or layout slots (AppView-only concepts).
      # So `layout` here only reaches body-class/CSS-selector level layout --
      # a known, accepted gap, not something the reader can close.
      #
      # `mode: :websocket` is kept for component-markup parity with the canvas
      # (some components render differently in websocket mode). The reader's
      # <head> deliberately does NOT use adapter.cdn_scripts, which would drag
      # in a connect attempt to a /canvas/reader/ws endpoint that doesn't exist.
      #
      # `inert: true` is the consequence of that omission: without cdn_scripts
      # there is no `sendEvent`, so buttons and radio groups that would call it
      # rendered as live controls which self-disabled and then threw a
      # ReferenceError on click (disc-095). Inert renders them disabled with an
      # explanatory title -- honest about being a preview -- rather than
      # defining a no-op `sendEvent` stub, which would preserve the lie.
      #
      # @param path [String, nil] source file, passed through to instance_eval
      #   so a DSL error names the actual file/line instead of "(eval)".
      #
      # `dsl` may actually be `.org` text -- detected the same content-based
      # way content.js/sandbox.js do client-side (StreamWeaver::Org::Reader.
      # streamweaver_org?) and converted via Org::Reader.to_dsl before eval,
      # same path the extension already uses. The converted text's line
      # numbers no longer match the original .org file's, so a DSL error in
      # a converted doc names the wrong line -- an accepted, precedented gap
      # (the extension's sandbox.js has the same limitation; org->DSL is a
      # real rewrite, not a 1:1 mapping).
      #
      # An `.org` file WITHOUT the marker (stream_weaver-gnj8 -- e.g. Browse
      # pointed at $HOME turns up ordinary org-mode notes, not StreamWeaver
      # docs) is caught before eval, not after: raw org markup is never
      # valid Ruby, so letting it fall through to instance_eval only ever
      # produces a confusing syntax error naming some fragment of prose. A
      # `.rb` file with no StreamWeaver DSL calls doesn't get the same
      # short-circuit -- it could legitimately be valid, unrelated Ruby
      # (or invalid for an unrelated reason), so eval-and-show-DSL-error
      # remains the right fallback there.
      def self.render_doc(dsl, path: nil)
        theme  = fallback_theme
        layout = fallback_layout
        if path.to_s.end_with?('.org') && !StreamWeaver::Org::Reader.streamweaver_org?(dsl)
          return Doc.new(html: not_a_streamweaver_doc_html, theme: theme, layout: layout, inline_stylesheets: [])
        end

        dsl = StreamWeaver::Org::Reader.to_dsl(dsl) if StreamWeaver::Org::Reader.streamweaver_org?(dsl)
        mini_app = StreamWeaver::App.new('reader', theme: theme, layout: layout)
        mini_app.instance_eval(dsl, path.to_s, 1)
        adapter = StreamWeaver::Adapter::AlpineJS.new(
          url_prefix: '/canvas/reader',
          mode: :websocket,
          inert: true
        )
        Doc.new(
          html: StreamWeaver::Views::AppContentView.new(mini_app, {}, adapter, false).call,
          theme: mini_app.theme,
          layout: mini_app.layout,
          inline_stylesheets: mini_app.inline_stylesheets
        )
      rescue ScriptError, StandardError => e
        Doc.new(
          html: "<div style='color:red;padding:1rem;font-family:monospace'>" \
                "<strong>DSL error:</strong> #{CGI.escapeHTML(e.message)}</div>",
          theme: theme,
          layout: layout,
          inline_stylesheets: []
        )
      end

      def self.render_dsl(dsl)
        render_doc(dsl).html
      end

      # Neutral, not red -- this isn't a bug in the doc or in canvas-read,
      # it's just the wrong kind of file (stream_weaver-gnj8). Red/"error"
      # styling here would read as "something's broken," which is the
      # opposite of what a stray personal org file browsed into deserves.
      def self.not_a_streamweaver_doc_html
        "<div style='color:#4b5563;padding:1rem;font-family:monospace'>" \
          "This doesn't look like a StreamWeaver doc -- no " \
          "<code>#+STREAMWEAVER_DSL:</code> header found. It's probably a " \
          "plain org-mode file.</div>"
      end
      private_class_method :not_a_streamweaver_doc_html

      private

      # Every Browse-related link carries this instead of the chrome's
      # narrower default (hx-select-oob="#sw-reader-nav" alone) -- Browse
      # needs the sidebar's own CONTENT to change between directories,
      # unlike normal docs/history navigation, which needs it to stay
      # untouched so accordion state survives (stream_weaver-8v1). A
      # boosted element's own hx-* attributes override its ancestor's, so
      # this widening stays scoped to exactly the links that opt into it.
      # One constant instead of nine hand-typed copies in the template:
      # dropping #sw-reader-nav from any one of them would silently stop
      # that link's swap from refreshing the nav bar.
      BROWSE_OOB = 'hx-select-oob="#sw-reader-nav, #sw-reader-files"'

      # The docs-mode counterpart of a bare GET /browse: sidebar and nav
      # render against an empty list, and #app-container falls back to the
      # same "pick a file" placeholder, because @doc is nil. Reached only
      # when the last doc was deleted out from under the reader
      # (stream_weaver-uvaj) -- @current_index stays unset, so the layout's
      # Prev/Next/Export block is skipped exactly as it is for a browsed file.
      def render_no_doc(list)
        @file_list       = list
        @doc             = nil
        @mermaid_zoom_js = MERMAID_ZOOM_JS
        erb :reader_layout, layout: false
      end

      # Populates every ivar reader_layout.erb's Browse sidebar needs,
      # shared by GET /browse and GET /open so both compute breadcrumbs and
      # the repo-root shortcut identically. Kept out of the ERB entirely --
      # the breadcrumb walk and repo_docs_root's filesystem/.git lookup are
      # controller work, not view formatting, and doing it here means it
      # runs once per request instead of once per render.
      def set_browse_ivars(dir)
        @browse_mode    = true
        @browse_dir     = dir
        @browse_entries = self.class.browse_entries(dir)
        @browse_parent  = dir == '/' ? nil : File.dirname(dir)

        parts = dir.split('/').reject(&:empty?)
        @breadcrumbs = parts.each_index.map { |i| [parts[i], "/#{parts[0..i].join('/')}"] }

        @repo_docs_root = self.class.repo_docs_root
      end
    end
  end
end
