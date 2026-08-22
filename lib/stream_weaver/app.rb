# frozen_string_literal: true

require 'digest'
require 'set'
require_relative 'resource'

module StreamWeaver
  # Main app class that holds the DSL block and manages the component tree
  class App
    include DisplayDSL

    # Mutable state used only while evaluating one render tree. App-definition
    # metadata intentionally remains on App so it survives fresh render states.
    class RenderState
      # Pass-scoped accumulators (button_counter, table_counter, seen_component_ids,
      # url_tab_keys) must also be captured in App#rewind_point -- a discarded
      # evaluation pass that skips one leaves ids/claims drifted on re-run.
      attr_accessor :components, :layout_slots, :button_counter, :seen_component_ids,
                    :current_form, :form_context, :current_checkbox_group,
                    :current_tabs, :current_breadcrumbs, :current_dropdown,
                    :current_menu, :current_modal, :modal_context, :current_deck,
                    :current_slide, :current_app_shell, :current_row_key_thunk,
                    :checkbox_keys, :action_tokens, :generation, :fragment_stack, :state_version,
                    :table_counter, :current_scope, :url_tab_keys, :url_params, :deferred_target,
                    :form_for_active, :form_for_submit_label, :form_for_cancel_label, :form_for_validate

      def initialize
        self.components = []
        self.layout_slots = {}
        self.button_counter = 0
        self.table_counter = 0
        self.seen_component_ids = Hash.new(0)
        self.checkbox_keys = []
        self.action_tokens = Set.new
        self.generation = "0"
        self.fragment_stack = []
        self.state_version = 0
        self.url_tab_keys = []
      end
    end

    # Built-in themes (custom themes checked via StreamWeaver.theme_exists?)
    BUILT_IN_THEMES = [:default, :dashboard, :document, :dark, :doc].freeze
    # For backwards compatibility
    VALID_THEMES = BUILT_IN_THEMES

    attr_reader :title, :block, :layout, :chrome, :theme, :theme_overrides, :scripts, :stylesheets, :inline_stylesheets, :fonts, :stream_block, :timers, :transient_keys, :favicon_value, :route_key, :routes, :route_rules, :resource_defs, :endpoints, :loading_indicators, :render_state, :actions, :action_updates, :action_primary

    # HTTP verbs supported by the `endpoint` DSL (real Rack routes, not state routing)
    ENDPOINT_VERBS = %i[get post put patch delete].freeze

    # Request params owned by Sinatra/StreamWeaver routing rather than by the app.
    # This is the single source of truth for that set: every param-to-state sync
    # strips them (server.rb / service.rb #sync_params_to_state, and
    # InteractionRunner::ROUTE_PARAMS, which adds its own dispatch-only params),
    # and a `url: true` tabs group can never claim one -- the key would validate
    # here and then silently never receive its value.
    ROUTE_OWNED_PARAMS = %w[app_id splat captures button_id].freeze

    # `deferred_target:` value meaning "run every deferred block inline". For
    # renders with no client to fetch anything afterwards -- a static export.
    # Never collides with a real target: fragment ids are all `sw-frag-`-prefixed.
    ALL_DEFERRED = "all"

    # Latch for the once-per-process lazy-tabs deprecation warning
    # (see #warn_lazy_tabs_deprecated). Writable so specs can re-arm it.
    class << self
      attr_accessor :lazy_tabs_deprecation_warned
    end

    # Paths/prefixes owned by StreamWeaver's own framework routes (see server.rb / service.rb).
    # An `endpoint` registered on one of these is never reached -- the internal route is always
    # defined first, and Sinatra dispatches to the first matching route. We still warn at
    # registration time so the collision is obvious instead of silently swallowed.
    RESERVED_ENDPOINT_EXACT = %w[/update /submit].freeze
    RESERVED_ENDPOINT_PREFIXES = %w[/action/ /event/ /form/ /theme/ /sw/].freeze

    # Content-type by extension for local files served via the /sw-asset/
    # route (App#local_asset, stylesheets: auto-detection). Shared with
    # server.rb's /sw-asset/ route handler.
    LOCAL_ASSET_MIME_TYPES = {
      'css' => 'text/css', 'js' => 'application/javascript', 'mjs' => 'application/javascript',
      'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif', 'svg' => 'image/svg+xml', 'webp' => 'image/webp', 'ico' => 'image/x-icon'
    }.freeze

    # @param assets_dirs [Array<String>] Extra directories (besides the
    #   calling script's own directory) that local_asset/stylesheets: are
    #   allowed to serve local files from (stream_weaver-1lo).
    def initialize(title, layout: :default, chrome: true, theme: :default, theme_overrides: {}, components: [], scripts: [], stylesheets: [], fonts: [], strict_ids: false, loading_indicators: true, assets_dirs: [], &block)
      @title = title
      @layout = layout
      @chrome = chrome
      @theme = validate_theme(theme)
      @theme_overrides = theme_overrides
      @block = block
      @render_state = RenderState.new
      @render_mutex = Mutex.new
      @state_key = :streamlit_state
      @_state = {}
      @strict_ids = strict_ids
      @loading_indicators = loading_indicators
      @_warned_duplicate_ids = Set.new
      @scripts = scripts
      @script_dir = File.dirname(File.expand_path(caller_locations(1, 1).first.path))
      @allowed_asset_dirs = ([@script_dir] + assets_dirs.map { |d| File.expand_path(d) }).uniq
      @stylesheets = stylesheets.map { |href| resolve_stylesheet_href(href) }
      @inline_stylesheets = []
      @fonts = fonts
      @transient_keys = Set.new
      @timers = []
      @favicon_value = nil
      @route_key = nil
      @routes = nil
      @routes_inverse = nil
      @route_parser = nil
      @route_builder = nil
      @route_rules   = []  # Array<RouteRule> — persistent, never cleared in rebuild
      @resource_defs = {}  # name(sym) → ResourceDefinition — persistent
      @endpoints     = []  # Array<{verb:, path:, block:}> — persistent, never cleared in rebuild
      @actions = {}
      @action_updates = {}
      @action_primary = {}
      @scope_registry = {}  # name(sym) → {kind:, retain:} — persistent, never cleared in rebuild
      components.each { |mod| singleton_class.include(mod) }
    end

    private

    def validate_theme(theme)
      theme = theme.to_sym
      # Accept built-in themes or custom registered themes
      return theme if BUILT_IN_THEMES.include?(theme) || StreamWeaver.theme_exists?(theme)
      warn "StreamWeaver: Unknown theme '#{theme}', falling back to :default"
      :default
    end

    public

    def layout_entry
      chrome ? LayoutRegistry[layout] : LayoutRegistry.chromeless
    end

    def state
      @_state
    end

    def components
      @render_state.components
    end

    def components=(value)
      @render_state.components = value
    end

    def layout_slots
      @render_state.layout_slots
    end

    def with_render_lock(&block)
      @render_mutex.synchronize(&block)
    end

    # Declare URL routing: maps a state key's values to URL paths.
    # Example: route_by :page, home: "/", about: "/about", settings: "/settings"
    def route_by(state_key, paths)
      @route_key = state_key
      @routes = paths.transform_keys(&:to_sym)
      @routes_inverse = @routes.invert
    end

    # Declare dynamic URL routing with custom path parser/builder lambdas.
    # parser receives the request path and returns a partial state hash or nil.
    # builder receives the current state and returns a path string or nil.
    def route_with(parser:, builder: nil)
      # Idempotent guard: don't re-register if same parser lambda already in chain
      @route_rules << RouteRule.new(parser: parser, builder: builder) \
        unless @route_rules.any? { |r| r.parser == parser }
    end

    def path_for_state(state)
      @route_rules.each do |rule|
        path = rule.builder&.call(state)
        return path if path
      end
      return @route_builder.call(state) if @route_builder  # legacy fallback (belt+suspenders)
      return unless @routes
      @routes[state[@route_key]&.to_sym]
    end

    def state_for_path(path)
      @route_rules.each do |rule|
        hash = rule.parser&.call(path)
        return hash if hash
      end
      return unless @routes_inverse
      val = @routes_inverse[path]
      val ? { @route_key => val } : nil
    end

    def routable?
      @route_rules.any? || @routes || @route_parser
    end

    def resource(name, store:, plural: nil, &block)
      unless @resource_defs.key?(name.to_sym)
        defn = ResourceDefinition.new(name, store, plural: plural)
        defn.instance_eval(&block) if block
        @resource_defs[name.to_sym] = defn
        @route_rules << RouteRule.new(
          parser:  defn.method(:parse_path),
          builder: defn.method(:build_path),
          source:  [:resource, name.to_sym]
        )
        define_path_helpers(defn)
      end
      @resource_defs[name.to_sym].render_if_active(self)
    end

    def page(name, path, &block)
      key = name.to_sym
      sk  = Resource::StateKeys
      unless @route_rules.any? { |r| r.source == [:page, key] }
        @route_rules << RouteRule.new(
          parser:  ->(p) { p == path ? { sk::RESOURCE => nil, sk::ACTION => key } : nil },
          builder: ->(st) { st[sk::ACTION] == key && st[sk::RESOURCE].nil? ? path : nil },
          source:  [:page, key]
        )
      end
      if @_state[sk::ACTION] == key && @_state[sk::RESOURCE].nil?
        evaluate_dsl_block(block)
      end
    end

    def route(name, path)
      page(name, path) {}
    end

    # Register a real HTTP endpoint (webhook receiver, JSON API, file download, etc.)
    # — the "never rewrite in Sinatra" escape hatch. Unlike `route`/`page` (which are
    # state-driven VIEW matchers), an `endpoint` is a genuine Rack route: it bypasses
    # StreamWeaver's state machinery, session, and CSRF handling entirely. The block
    # receives the raw `Rack::Request` and its return value is converted to a response:
    #
    #   Hash            -> 200 application/json (JSON.generate'd)
    #   String          -> 200 text/html
    #   [status, headers, body] Array -> passed through to Rack verbatim
    #   anything else   -> 200 text/plain (#to_s)
    #
    # @example
    #   endpoint :get, "/api/status" do |req|
    #     { ok: true, uptime: 42 }
    #   end
    #
    #   endpoint :post, "/webhook/github" do |req|
    #     payload = req.body.read
    #     [202, {}, "queued"]
    #   end
    #
    # Idempotent: repeated registration of the same verb+path across `rebuild_with_state`
    # calls (every request) keeps only the first block, mirroring `resource`/`route_with`.
    def endpoint(verb, path, &block)
      verb = verb.to_sym
      unless ENDPOINT_VERBS.include?(verb)
        raise ArgumentError, "endpoint: unsupported verb #{verb.inspect} (must be one of #{ENDPOINT_VERBS.join(', ')})"
      end
      raise ArgumentError, "endpoint: block required" unless block

      return if @endpoints.any? { |e| e[:verb] == verb && e[:path] == path }

      if reserved_endpoint_path?(path)
        warn "StreamWeaver: endpoint #{verb.to_s.upcase} #{path} collides with a StreamWeaver-internal " \
             "route and will never be reached — the internal route always wins."
      end

      @endpoints << { verb: verb, path: path, block: block }
    end

    # Look up a registered endpoint by verb + exact path. Used by SinatraApp/Service
    # route dispatch at request time.
    def find_endpoint(verb, path)
      verb = verb.to_sym
      @endpoints.find { |e| e[:verb] == verb && e[:path] == path }
    end

    # Points @_state at the given state object without running a full
    # rebuild (#rebuild_with_state). Named-action dispatch skips the
    # pre-dispatch discovery rebuild by design (see InteractionRunner
    # #discovery_required?), so without this, app-level state helpers
    # reached from inside the handler (flash, open_modal, close_modal,
    # show_toast, dismiss_toast, clear_toasts -- anything that reads/writes
    # @_state directly rather than taking state as an argument) would
    # target the previous request's now-stale state object, and any writes
    # made through them would be silently discarded once the post-dispatch
    # rebuild repoints @_state at this request's state (stream_weaver-dwi).
    def bind_dispatch_state(current_state)
      @_state = current_state
    end

    # @param url_params [Hash, nil] params of the URL being rendered; nil when no
    #   URL is behind this render. See #tab_index_source for what reads it.
    # @param deferred_target [String, nil] The fragment id this pass is rendering
    #   for. A `defer: true` fragment executes its block only when it is that
    #   fragment or one of its ancestors (see #fragment); every other pass
    #   renders its placeholder instead.
    def rebuild_with_state(current_state, generation: "0", state_version: 0, url_params: nil, deferred_target: nil)
      @_state = current_state
      @render_state = RenderState.new
      @render_state.generation = generation.to_s
      @render_state.state_version = state_version.to_i
      @render_state.url_params = url_params
      @render_state.deferred_target = deferred_target&.to_s
      apply_scope_lifecycle
      flash_messages if chrome
      evaluate_dsl_block(@block)
      @render_state.checkbox_keys = collect_checkbox_keys(components)
      @timers_frozen = true
    end

    # Returns [scope_name, key] pairs (scope_name nil for flat/form-context
    # checkboxes) so InteractionRunner#handle_unchecked_checkboxes can clear
    # an unchecked scope-nested "live" checkbox at state[scope_name][key]
    # instead of a same-named flat key (FAC-P3.1 handoff).
    def collect_checkbox_keys(component_list)
      component_list.each_with_object([]) do |component, keys|
        keys << [component.options[:scope_name], component.key] if component.is_a?(Components::Checkbox)
        keys.concat(collect_checkbox_keys(component.children)) if component.respond_to?(:children) && component.children
        if component.is_a?(Components::Modal) && component.footer_component&.children
          keys.concat(collect_checkbox_keys(component.footer_component.children))
        end
      end
    end
    private :collect_checkbox_keys

    # Capture DSL components for a named layout slot.
    # Components in a slot are rendered outside #app-container (static chrome).
    #
    # @param name [Symbol] Slot identifier (:header, :sidebar_left, :footer, etc.)
    def layout_slot(name, &block)
      layout_slots[name] ||= []
      parent_components = components
      self.components = layout_slots[name]
      evaluate_dsl_block(block)
      self.components = parent_components
    end

    # Find a component by its key (for callback execution)
    def find_component_by_key(key, components_list = components)
      components_list.each do |component|
        return component if component.respond_to?(:key) && component.key == key
        # Search in children if component has them
        if component.respond_to?(:children) && component.children
          found = find_component_by_key(key, component.children)
          return found if found
        end
        # Also search modal footer if present
        if component.is_a?(Components::Modal) && component.footer_component&.children
          found = find_component_by_key(key, component.footer_component.children)
          return found if found
        end
      end
      nil
    end

    def generate
      rebuild_with_state(@_state)  # pre-populate @route_rules before Sinatra starts
      SinatraApp.create(self)
    end

    # Save and restore form DSL ivars around a block — used by ResourceDefinition
    # when executing override blocks so they can't leave form state dirty.
    def with_clean_form_context
      saved_form    = render_state.current_form
      saved_context = render_state.form_context
      yield
    ensure
      render_state.current_form = saved_form
      render_state.form_context = saved_context
    end

    def has_charts?
      components_include?(Components::ChartBase)
    end

    private

    def components_include?(klass)
      components.any? { |c| c.is_a?(klass) || nested_include?(c, klass) }
    end

    def nested_include?(component, klass)
      return false unless component.respond_to?(:children) && component.children
      component.children.any? { |c| c.is_a?(klass) || nested_include?(c, klass) }
    end

    public

    def action(name, updates: nil, primary: nil, &handler)
      raise ArgumentError, "action: block required" unless handler
      name = name.to_sym
      existing = @actions[name]
      if existing && existing.source_location != handler.source_location
        raise ArgumentError, "action #{name.inspect} is already registered with a different block"
      end
      @actions[name] ||= handler
      normalized_updates = Array(updates).compact.map(&:to_sym)
      if @action_updates.key?(name) && @action_updates[name] != normalized_updates
        raise ArgumentError, "action #{name.inspect} is already registered with different updates"
      end
      @action_updates[name] ||= normalized_updates

      normalized_primary = primary&.to_sym
      if @action_primary.key?(name) && @action_primary[name] != normalized_primary
        raise ArgumentError, "action #{name.inspect} is already registered with a different primary:"
      end
      @action_primary[name] = normalized_primary unless @action_primary.key?(name)
    end

    def action_definition_digest
      Digest::SHA256.hexdigest(([StreamWeaver::VERSION] + actions.keys.map(&:to_s).sort).join("\0"))
    end

    # @param primary [Symbol, String, nil] Names a sibling fragment to swap as
    #   this response's primary target instead of the button's own enclosing
    #   fragment (stream_weaver-78a) -- e.g. a board's "View" button
    #   refreshing a detail pane without resending the whole board. Falls
    #   back to the action-level default (registered via `action(...,
    #   primary:)`) the same way `updates:` does; resolved against the
    #   post-rebuild tree by InteractionRunner, so a name that doesn't match
    #   any fragment there falls back to a full-container response rather
    #   than silently doing nothing.
    def action_token(name, key, fragment: nil, updates: nil, primary: nil)
      name = name.to_sym
      raise ArgumentError, "unknown named action #{name.inspect}" unless actions.key?(name)
      scopes = Array(updates.nil? ? action_updates[name] : updates).compact.map(&:to_s)
      primary_target = primary.nil? ? action_primary[name] : primary
      payload = { a: name, k: key, d: action_definition_digest, g: render_state.generation }
      payload[:f] = fragment if fragment
      payload[:u] = scopes unless scopes.empty?
      payload[:p] = primary_target.to_s if primary_target
      token = ActionToken.encode(payload)
      render_state.action_tokens << ActionToken.fingerprint(token)
      token
    end

    # =========================================
    # App-specific display components
    # =========================================

    # @param defer [Boolean] Render the shell now and fetch this fragment's
    #   content afterwards -- the Turbo `turbo_frame_tag ..., src:` equivalent.
    #   The block does not run on the initial render at all, so a slow region
    #   cannot delay the page.
    # @param lazy [Boolean] Hold the deferred fetch until the fragment is
    #   visible -- Turbo's `loading="lazy"`. Implies `defer:`, the way Turbo's
    #   `loading` only means anything on a frame that loads from `src`.
    # @param placeholder [String, Proc, nil] What stands in until the content
    #   lands. A String renders as text, a Proc is evaluated as DSL, nil gets a
    #   small spinner. Only read when `defer:` is set.
    def fragment(name, defer: false, lazy: false, placeholder: nil, &block)
      defer ||= lazy
      name = validate_scalar_key!(name, context: "fragment")
      raise ArgumentError, "fragment: block required" unless block
      raise ArgumentError, "fragment: placeholder: requires defer: true" if placeholder && !defer

      safe_name = name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|\-\z/, "")
      raise ArgumentError, "fragment: name must contain a letter or number" if safe_name.empty?
      candidate_id = if render_state.fragment_stack.empty?
        "sw-frag-#{safe_name}"
      else
        "#{render_state.fragment_stack.last}--#{safe_name}"
      end
      id = disambiguate_component_id(candidate_id, label: name.to_s, source_loc: block.source_location)
      deferred = defer && !materializes_deferred?(id)
      component = Components::Fragment.new(name, id, deferred: deferred, lazy: lazy)
      components << component
      parent = components
      render_state.fragment_stack << id
      self.components = []
      evaluate_dsl_block(deferred ? placeholder_block(placeholder) : block)
      component.children = components
      self.components = parent
      component
    ensure
      render_state.fragment_stack.pop if id && render_state.fragment_stack.last == id
    end

    # True when this pass is the fetch that materializes fragment `id`, or the
    # fetch of a fragment nested inside it. Nested fragment ids are literally
    # `parent--child` (see #fragment), so an ancestor is a prefix of its
    # descendants -- which is what lets a deferred fragment nested inside
    # another deferred fragment be reached by a second fetch.
    def materializes_deferred?(id)
      target = render_state.deferred_target
      return false unless target
      return true if target == ALL_DEFERRED

      target == id || target.start_with?("#{id}--")
    end
    private :materializes_deferred?

    def placeholder_block(placeholder)
      case placeholder
      when Proc then placeholder
      when nil then proc { spinner(size: :sm, label: "Loading…") }
      else proc { text placeholder.to_s }
      end
    end
    private :placeholder_block

    def lesson_text(content_or_options = nil, **options, &block)
      if content_or_options.is_a?(String)
        glossary = options[:glossary] || {}
        lesson_component = Components::LessonText.new(glossary: glossary)
        components << lesson_component
        lesson_component.children = parse_lesson_string(content_or_options, glossary)
      else
        opts = content_or_options.is_a?(Hash) ? content_or_options.merge(options) : options
        glossary = opts[:glossary] || {}
        with_container(Components::LessonText.new(glossary: glossary), &block)
      end
    end

    def term(term_key, **options)
      components << Components::Term.new(term_key, **options)
    end

    def checkbox_group(key, **options, &block)
      @_state[key] = options[:default] || [] unless @_state.key?(key)

      group_component = Components::CheckboxGroup.new(key, **options)
      components << group_component

      parent_components = components
      render_state.current_checkbox_group = group_component
      self.components = []

      evaluate_dsl_block(block)

      group_component.children = components
      self.components = parent_components
      render_state.current_checkbox_group = nil
    end

    def item(value, &block)
      item_component = Components::CheckboxItem.new(value)
      capture_children_then_append(item_component, &block)
    end

    # =========================================
    # State scopes (namespacing + lifetime)
    # =========================================

    # Declare a named, kind-tagged, lifetime-managed sub-hash of state.
    # `form(name) { }` is sugar over `scope(name, kind: :form) { }` -- same
    # storage shape (`state[name] = { field => value, ... }`), now nameable,
    # kind-tagged, and (unless retain: true) auto-reset when its owning
    # routing discriminant changes between rebuilds (see #apply_scope_lifecycle).
    #
    # @param name [Symbol] scope name -- becomes the top-level state key
    # @param kind [Symbol] one of :form, :resource, :fragment, :app
    # @param retain [Boolean] opt out of auto-reset (default false)
    # @yield [Hash] the scope's sub-hash, for direct reads/writes; the block
    #   also runs in App's DSL context, so nested field/component calls work
    def scope(name, kind:, retain: false, &block)
      name = name.to_sym
      register_scope(name, kind: kind, retain: retain)
      @_state[name] ||= {}
      return @_state[name] unless block

      saved_scope = render_state.current_scope
      render_state.current_scope = name
      evaluate_dsl_block(block, @_state[name])
      render_state.current_scope = saved_scope
      @_state[name]
    end

    # Names of every scope registered so far (via `scope` or `form`) --
    # used by SessionStore to know which top-level hash values are safe to
    # recurse one level into for blank-stripping (FAC-P3.1 decision §7).
    def scope_names
      @scope_registry.keys
    end

    # =========================================
    # Form container with special context
    # =========================================

    def form(name, **options, &block)
      name = name.to_sym
      scope(name, kind: :form)
      form_component = Components::Form.new(name, **options)
      components << form_component

      parent_components = components
      render_state.current_form = form_component
      render_state.form_context = { name: name }
      self.components = []

      evaluate_dsl_block(block)

      form_component.children = components
      self.components = parent_components
      render_state.current_form = nil
      render_state.form_context = nil
    end

    def submit(label, &block)
      raise "submit can only be used inside a form block" unless render_state.current_form
      render_state.current_form.set_submit(label, &block)
    end

    def cancel(label)
      raise "cancel can only be used inside a form block" unless render_state.current_form
      render_state.current_form.set_cancel(label)
    end

    def form_context
      render_state.form_context
    end

    # =========================================
    # form_for -- resource-bound form (builds on `form`, FAC-P3.2)
    # =========================================

    # Generates a full create/update form bound to a resource's store + fields
    # (form-for.md): seeds from `record:` only on first render for that record
    # id and never re-seeds an in-progress edit (reuses the :resource-kind
    # scope auto-reset from `state-scopes.md` §4/§7 -- no hand-rolled seeded_key
    # guard needed), infers create vs. update from record identity, renders
    # fields via the shared Resource::FieldInput table, and wires submit to
    # coerce -> validate -> store.create/update -> flash + PRG transition.
    #
    # @param resource_name [Symbol, nil] a registered `resource` name to reuse
    #   its store/fields, or nil when passing store:/fields: directly
    # @param record [Hash, nil] the record being edited; nil/no :id means create
    # @param store [#all,#find,#create,#update,#destroy] required unless resource_name given
    # @param fields [Array<Field>] required unless resource_name given
    # @param name [Symbol, nil] scope/form name override (default "#{singular}_form")
    # @param on_success [Proc, nil] instance_exec'd with the new/updated id;
    #   overrides the resource's default show/index transition
    # @param validate [Proc, nil] called with the coerced values, returns
    #   Hash[field, Array[String]] of extra validation errors (empty/nil = valid)
    def form_for(resource_name = nil, record: nil, store: nil, fields: nil, name: nil, on_success: nil, validate: nil, &block)
      defn = resource_name && @resource_defs[resource_name.to_sym]
      raise ArgumentError, "form_for: unknown resource #{resource_name.inspect}" if resource_name && !defn

      store  ||= defn&.store
      fields ||= defn&.fields
      raise ArgumentError, "form_for: no store given and no resource #{resource_name.inspect} registered" unless store
      raise ArgumentError, "form_for: no fields given and no resource #{resource_name.inspect} registered" unless fields
      Resource::Store.validate!(store, resource_name || name || :form_for) unless defn

      singular   = resource_name&.to_s || name&.to_s&.sub(/_form\z/, '')
      singular   = "record" if singular.nil? || singular.empty?
      scope_name = (name || :"#{singular}_form").to_sym
      errors_key = :"#{scope_name}_errors"
      is_update  = !record.nil? && !record[:id].nil?

      scope(scope_name, kind: :resource) do |s|
        fields.each { |f| s[f.name] = record[f.name] unless s.key?(f.name) } if record
      end

      form(scope_name) do
        if (errs = state[errors_key]) && !errs.empty?
          alert(variant: :error, title: "Please fix the following") do
            errs.each { |field, msgs| Array(msgs).each { |m| text "#{field.to_s.tr('_', ' ').capitalize}: #{m}" } }
          end
        end

        fields.each { |f| instance_exec(f, &Resource::FieldInput::RENDER) }

        render_state.form_for_submit_label = is_update ? "Save" : "Create"
        render_state.form_for_cancel_label = nil
        render_state.form_for_validate     = validate
        render_state.form_for_active       = true
        instance_exec(&block) if block
        render_state.form_for_active       = false

        submit(render_state.form_for_submit_label) do |raw_values|
          form_for_submit(fields: fields, raw_values: raw_values, store: store, record: record,
                           is_update: is_update, errors_key: errors_key, defn: defn,
                           on_success: on_success, validate_proc: render_state.form_for_validate,
                           singular: singular)
        end
        cancel(render_state.form_for_cancel_label) if render_state.form_for_cancel_label
      end
    end

    # Configures the auto-generated form's submit button label -- only valid
    # inside a `form_for` block (dual-purpose reader/setter, like `edit_view`).
    def submit_label(text = nil)
      raise "submit_label can only be used inside a form_for block" unless render_state.form_for_active
      text.nil? ? render_state.form_for_submit_label : (render_state.form_for_submit_label = text)
    end

    # Configures the auto-generated form's cancel button label (omitted by
    # default) -- only valid inside a `form_for` block.
    def cancel_label(text = nil)
      raise "cancel_label can only be used inside a form_for block" unless render_state.form_for_active
      text.nil? ? render_state.form_for_cancel_label : (render_state.form_for_cancel_label = text)
    end

    # Registers an extra validation hook for the enclosing `form_for`: called
    # with the coerced submitted values, returns Hash[field, Array[String]] of
    # additional errors (merged with coercion failures) -- only valid inside a
    # `form_for` block.
    def validate(&block)
      raise "validate can only be used inside a form_for block" unless render_state.form_for_active
      render_state.form_for_validate = block
    end

    # =========================================
    # Form input components
    # =========================================

    def text_field(key, **options)
      @transient_keys << key if options.delete(:transient)
      initialize_form_state(key, options, options[:default] || "")
      components << Components::TextField.new(key, **options)
    end

    def text_area(key, **options)
      @transient_keys << key if options.delete(:transient)
      initialize_form_state(key, options, options[:default] || "")
      components << Components::TextArea.new(key, **options)
    end

    # Native <input type=date>, state-bound like text_field. Value is stored
    # as an ISO 8601 string ("YYYY-MM-DD"); use Components::DateField.to_date
    # to coerce it to a Date (03 gap #4: rivet hand-parsed Date from a raw
    # text_field because date_field didn't exist).
    def date_field(key, **options)
      @transient_keys << key if options.delete(:transient)
      initialize_form_state(key, options, options[:default] || "")
      components << Components::DateField.new(key, **options)
    end

    def code_editor(key, language: :ruby, readonly: true, height: "400px", **options)
      initialize_form_state(key, options, options[:default] || "")
      components << Components::CodeEditor.new(key, language: language, readonly: readonly, height: height, **options)
    end

    def checkbox(key, label, **options)
      initialize_form_state(key, options, false)
      components << Components::Checkbox.new(key, label, **options)
    end

    def select(key, choices, **options)
      initialize_form_state(key, options, options[:default] || "", skip_if_exists: true)
      components << Components::Select.new(key, choices, **options)
    end

    def radio_group(key, choices, **options)
      initialize_form_state(key, options, "")
      components << Components::RadioGroup.new(key, choices, **options)
    end

    def tag_buttons(key, tags, **options)
      @_state[key] ||= nil
      components << Components::TagButtons.new(key, tags, **options)
    end

    # Tag/chip multi-select bound to a state array (03 gap #8: rivet's
    # "* "-prefixed toggle buttons faking a checked state). multi: false
    # binds a single scalar value (radio-style) instead of an array.
    # Works inside form/scope like text_field/select.
    def chip_group(key, choices = [], multi: true, **options)
      initialize_form_state(key, options, options[:default] || (multi ? [] : nil))
      components << Components::ChipGroup.new(key, choices, multi: multi, **options)
    end

    # =========================================
    # Interactive components
    # =========================================

    def button(label, action: nil, key: nil, id: nil, **options, &block)
      raise ArgumentError, "button cannot use both action: and a block" if action && block
      key = validate_scalar_key!(key || id, context: "button")
      if action
        row_key = render_state.current_row_key_thunk&.value
        action_key = key || row_key
        action_key = validate_scalar_key!(action_key, context: "named action button")
        raise ArgumentError, "named action button: key: is required" if action_key.nil?
        options[:action_token] = action_token(
          action, action_key,
          fragment: render_state.fragment_stack.last,
          updates: options.delete(:updates),
          primary: options.delete(:primary)
        )
      end
      # Generate stable ID: use source location for buttons with blocks,
      # fallback to counter for blockless buttons (submit: false)
      # If key: is provided, mix it in to disambiguate buttons in loops
      # (order-independent -- unlike a positional index, reordering the
      # collection doesn't change a keyed button's id). Inside a table's
      # component cell, the row's key is auto-mixed in too (FAC-P2.1
      # decision 3), on top of any explicit key: also passed.
      if block || action
        row_key = render_state.current_row_key_thunk&.value
        combined_key = [row_key, key].compact
        source_loc = block ? block.source_location.join(':') : "action:#{action}"
        id_input = combined_key.any? ? "#{label}:#{combined_key.join(':')}" : "#{label}:#{source_loc}"
        stable_id = Digest::MD5.hexdigest(id_input)[0..7]
      else
        render_state.button_counter += 1
        stable_id = render_state.button_counter.to_s
      end
      # Pass modal context to button so it can close the modal via Alpine
      options[:modal_context] = render_state.modal_context if render_state.modal_context
      btn = Components::Button.new(label, stable_id, **options, &block)
      btn.id = disambiguate_component_id(btn.id, label: label, source_loc: block&.source_location)
      components << btn
    end

    # Wraps arbitrary composed content (any DSL components) as a single
    # click target -- the click-target equivalent of what card/div already
    # do for layout, so a whole card/row can be one dispatch target instead
    # of a trailing "View" button glued to the bottom.
    #
    #   clickable(action: :select, key: story[:id]) { header4 story[:slug]; badge story[:state] }
    #   clickable(href: "/stories/#{story[:id]}") { header4 story[:slug] }
    #
    # action: dispatches exactly like a named-action button (same token,
    # fragment context, and current-row key: inside a table cell); href:
    # renders a plain navigation <a> for routed pages. Mutually exclusive.
    def clickable(action: nil, href: nil, key: nil, **options, &block)
      if action.nil? == href.nil?
        raise ArgumentError, "clickable requires exactly one of action: or href:"
      end

      if href
        component = Components::Clickable.new(href: href, **options)
        return with_container(component, &block)
      end

      require 'digest/md5'
      row_key = render_state.current_row_key_thunk&.value
      action_key = key || row_key
      action_key = validate_scalar_key!(action_key, context: "clickable")
      raise ArgumentError, "clickable action: key: is required" if action_key.nil?
      options[:action_token] = action_token(
        action, action_key,
        fragment: render_state.fragment_stack.last,
        updates: options.delete(:updates),
        primary: options.delete(:primary)
      )

      combined_key = [row_key, key].compact
      id_input = combined_key.any? ? "clickable:#{action}:#{combined_key.join(':')}" : "clickable:#{action}:#{block&.source_location&.join(':')}"
      stable_id = Digest::MD5.hexdigest(id_input)[0..7]
      wrapper_id = "clickable_#{action}_#{stable_id}"

      component = Components::Clickable.new(wrapper_id: wrapper_id, **options)
      component.id = disambiguate_component_id(component.id, label: "clickable_#{action}", source_loc: block&.source_location)
      with_container(component, &block)
    end

    # =========================================
    # Chart DSL methods
    # =========================================

    def bar_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      components << Components::BarChart.new(
        data: data, file: file, path: path, labels: labels, values: values, **options, &block
      )
    end

    def hbar_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      bar_chart(data: data, file: file, path: path, labels: labels, values: values, horizontal: true, **options, &block)
    end

    def line_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      components << Components::LineChart.new(
        data: data, file: file, path: path, labels: labels, values: values, **options, &block
      )
    end

    def sparkline(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      line_chart(data: data, file: file, path: path, labels: labels, values: values, sparkline: true, **options, &block)
    end

    def area_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      line_chart(data: data, file: file, path: path, labels: labels, values: values, fill: true, **options, &block)
    end

    def pie_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      components << Components::PieChart.new(
        data: data, file: file, path: path, labels: labels, values: values, **options, &block
      )
    end

    def doughnut_chart(data: nil, file: nil, path: nil, labels: nil, values: nil, **options, &block)
      pie_chart(data: data, file: file, path: path, labels: labels, values: values, doughnut: true, **options, &block)
    end

    def stacked_bar_chart(data: nil, file: nil, path: nil, **options, &block)
      components << Components::StackedBarChart.new(data: data, file: file, path: path, **options, &block)
    end

    # =========================================
    # Navigation DSL methods
    # =========================================

    def tabs(key, variant: :line, url: false, **options, &block)
      tabs_component = Components::Tabs.new(key, variant: variant, url: url, **options)
      claim_url_tab_key!(tabs_component) if url
      # `url: true` with lazy has already raised above, so reaching here with
      # lazy set means the deprecated POST-morph mode.
      warn_lazy_tabs_deprecated(key) if tabs_component.lazy

      # Coerce before the block: `tab` reads this index mid-evaluation to decide
      # which lazy panels to evaluate, so it has to be a usable Integer by then.
      @_state[key] = coerce_tab_index(tab_index_source(key, url: url))

      components << tabs_component

      parent_components = components
      render_state.current_tabs = tabs_component
      self.components = []
      rewind_render_state = rewind_point if tabs_component.lazy

      evaluate_dsl_block(block)

      # Clamp after the block: the tab count doesn't exist until the nested
      # `tab` calls have appended, and an index past the end matches no panel.
      requested = @_state[key]
      @_state[key] = 0 unless requested.between?(0, components.size - 1)

      if rewind_render_state && @_state[key] != requested
        # Lazy tabs pick which blocks to evaluate while the block is still
        # running, so an out-of-range index skipped every panel and left the
        # group empty. The corrected index needs a second pass -- and the first
        # pass is discarded, so its render_state marks are rewound with it.
        self.components = []
        rewind_render_state.call
        evaluate_dsl_block(block)
      end

      tabs_component.children = components
      self.components = parent_components
      render_state.current_tabs = nil
    end

    # A tab index reaches state from a URL param, a stale session, or a tab
    # group that shrank under it, so it can arrive as anything at all. Values
    # with no sensible integer reading collapse to the first tab; integer
    # strings are kept, since `url: true` groups read their index from params.
    def coerce_tab_index(value)
      case value
      when Integer then value
      # \A\d+\z + base-10, matching sw-route-tabs.js exactly -- Integer() would
      # read a leading zero as octal and disagree with the client on ?view=010.
      when String then value.match?(/\A\d+\z/) ? value.to_i : 0
      else 0
      end
    end
    private :coerce_tab_index

    # Only the URL decides a `url: true` group's index. State cannot serve even
    # as a fallback: the param has already been synced into it, so a stale index
    # is indistinguishable from a fresh one -- and an absent param means tab 0
    # as surely as `?view=0` does. Renders with no URL behind them (a POST
    # morph, a canvas push, an export) keep the index they were handed.
    def tab_index_source(key, url:)
      url_params = render_state.url_params
      return @_state[key] unless url && url_params

      url_params[key.to_s]
    end
    private :tab_index_source

    # Captures the render_state accumulators that an evaluation pass writes to,
    # returning a callable that puts them back. Used where a pass is thrown away
    # and re-run (see #tabs): re-running without rewinding double-counts, and
    # ids that shift between renders break dispatch for exactly the requests the
    # re-run exists to rescue. Mirrors #with_clean_form_context, but the rewind
    # is deliberately explicit -- the caller only knows it needs one after the
    # block has already run.
    def rewind_point
      button_counter = render_state.button_counter
      table_counter = render_state.table_counter
      seen_component_ids = render_state.seen_component_ids.dup
      url_tab_keys = render_state.url_tab_keys.dup

      lambda do
        render_state.button_counter = button_counter
        render_state.table_counter = table_counter
        render_state.seen_component_ids = seen_component_ids
        render_state.url_tab_keys = url_tab_keys
      end
    end
    private :rewind_point

    def tab(label, **options, &block)
      tab_component = Components::Tab.new(label, **options)

      # Lazy tabs: skip EVALUATING inactive tab blocks entirely, not just
      # rendering them. The block is where apps load data, so lazy that only
      # skipped the render layer (adapter) still paid the full data cost for
      # every hidden tab. The adapter already renders inactive lazy panels as
      # a placeholder comment, so an empty-children Tab is consistent; tab
      # switches post the new index and the full morph re-render evaluates
      # the newly-active block.
      current = render_state.current_tabs
      if current&.lazy
        index = components.size
        active = @_state[current.key]
        if index != active
          components << tab_component
          return tab_component
        end
      end

      capture_children_then_append(tab_component, &block)
    end

    # Lazy tabs fetch the newly-active panel with an `hx-post` morph, which a
    # canvas page has no route for -- inactive panels there render as a
    # placeholder comment and can never receive content (beads
    # stream_weaver-pkh). Route tabs are the direction this goes instead, and a
    # lazy route-tab mode is meant to replace this one; until then the mode
    # still works exactly as before and only says so.
    #
    # Once per process, not once per declaration: a lazy app re-evaluates its
    # whole DSL on every interaction, so a per-render warning would bury the
    # logs of the busiest apps -- the ones most likely to be using lazy.
    def warn_lazy_tabs_deprecated(key)
      return if self.class.lazy_tabs_deprecation_warned

      self.class.lazy_tabs_deprecation_warned = true
      warn "StreamWeaver: tabs #{key.inspect} -- lazy: true is deprecated. Switching a lazy tab " \
           "round-trips to the server, which canvas cannot serve (stream_weaver-pkh). Prefer route " \
           "tabs (tabs #{key.inspect}, url: true); lazy route tabs will replace this mode. " \
           "Warned once per process."
    end
    private :warn_lazy_tabs_deprecated

    # Validates and records a `url: true` tabs key. Keys live on render_state so
    # tracking resets with every DSL evaluation -- the same app re-rendering per
    # request must not look like a duplicate declaration of itself.
    def claim_url_tab_key!(group)
      key = group.key
      name = key.to_s

      raise ArgumentError, "tabs #{key.inspect}: url: true does not support lazy: true yet" if group.lazy
      raise ArgumentError, "tabs #{key.inspect}: reserved request param -- pick another key for url: true tabs" if ROUTE_OWNED_PARAMS.include?(name)
      raise ArgumentError, "tabs #{key.inspect}: already claimed by another url: true tabs group" if render_state.url_tab_keys.include?(name)

      render_state.url_tab_keys << name
    end
    private :claim_url_tab_key!

    def breadcrumbs(separator: "/", **options, &block)
      breadcrumbs_component = Components::Breadcrumbs.new(separator: separator, **options)
      components << breadcrumbs_component

      parent_components = components
      render_state.current_breadcrumbs = breadcrumbs_component
      self.components = []

      evaluate_dsl_block(block)

      breadcrumbs_component.children = components
      self.components = parent_components
      render_state.current_breadcrumbs = nil
    end

    def crumb(label, href: nil, **options)
      components << Components::Crumb.new(label, href: href, **options)
    end

    def dropdown(**options, &block)
      dropdown_component = Components::Dropdown.new(**options)
      components << dropdown_component

      render_state.current_dropdown = dropdown_component
      evaluate_dsl_block(block)
      render_state.current_dropdown = nil
    end

    def trigger(&block)
      raise "trigger can only be used inside a dropdown block" unless render_state.current_dropdown

      trigger_component = Components::DropdownTrigger.new
      parent_components = components
      self.components = []

      evaluate_dsl_block(block)

      trigger_component.children = components
      self.components = parent_components
      render_state.current_dropdown.trigger_component = trigger_component
    end

    def menu(**options, &block)
      raise "menu can only be used inside a dropdown block" unless render_state.current_dropdown

      menu_component = Components::Menu.new(**options)
      parent_components = components
      render_state.current_menu = menu_component
      self.components = []

      evaluate_dsl_block(block)

      menu_component.children = components
      self.components = parent_components
      render_state.current_dropdown.menu_component = menu_component
      render_state.current_menu = nil
    end

    def menu_item(label, style: :default, **options, &block)
      raise "menu_item can only be used inside a menu block" unless render_state.current_menu
      render_state.button_counter += 1
      item = Components::MenuItem.new(label, style: style, **options, &block)
      item.instance_variable_set(:@id, "menu_item_#{render_state.button_counter}")
      components << item
    end

    def menu_divider
      raise "menu_divider can only be used inside a menu block" unless render_state.current_menu
      components << Components::MenuDivider.new
    end

    # =========================================
    # Modal DSL methods
    # =========================================

    def modal(key, title: nil, size: :md, **options, &block)
      open_key = :"#{key}_open"
      @_state[open_key] = false unless @_state.key?(open_key)

      modal_component = Components::Modal.new(key, title: title, size: size, **options)
      components << modal_component

      parent_components = components
      render_state.current_modal = modal_component
      render_state.modal_context = { key: key }
      self.components = []

      evaluate_dsl_block(block)

      modal_component.children = components
      self.components = parent_components
      render_state.current_modal = nil
      render_state.modal_context = nil
    end

    def modal_footer(**options, &block)
      raise "modal_footer can only be used inside a modal block" unless render_state.current_modal

      footer_component = Components::ModalFooter.new(**options)
      parent_components = components
      self.components = []

      evaluate_dsl_block(block)

      footer_component.children = components
      self.components = parent_components
      render_state.current_modal.footer_component = footer_component
    end

    def open_modal(key)
      @_state[:"#{key}_open"] = true
    end

    def close_modal(key)
      @_state[:"#{key}_open"] = false
    end

    # =========================================
    # Feedback DSL methods (App-only)
    # =========================================

    def toast_container(position: :top_right, duration: 5000, **options)
      @_state[:_toasts] ||= []
      components << Components::ToastContainer.new(position: position, duration: duration, **options)
    end

    def show_toast(message, variant: :info, duration: nil)
      @_state[:_toasts] ||= []
      toast_id = "toast_#{Time.now.to_f.to_s.gsub('.', '_')}_#{rand(1000)}"
      toast = { id: toast_id, message: message, variant: variant }
      toast[:duration] = duration if duration
      @_state[:_toasts] << toast
    end

    def dismiss_toast(toast_id)
      @_state[:_toasts] ||= []
      @_state[:_toasts].reject! { |t| t[:id] == toast_id }
    end

    def clear_toasts
      @_state[:_toasts] = []
    end

    # =========================================
    # Flash: one-shot, same-request messaging (FAC-P3.2b, flash-prg.md)
    # =========================================

    # Hash-like accessor backed by state[:_flash] (mirrors how `state` itself
    # is exposed): `flash[:notice] = "Person created."`. flash.now-only
    # semantics -- visible in the render that answers this request, gone by
    # the next one (session persistence excludes :_flash entirely; see
    # SessionStore::Base#filter and Service#set_app_state). Not merged with
    # the toast system: toast is a persistent, dismissible list; flash is a
    # one-shot PRG-shaped message, deliberately a different lifetime.
    def flash
      @_state[:_flash] ||= {}
    end

    # Renders whatever key/value pairs are present in the current flash as
    # Alert summaries, mapping known keys to Alert variants (:notice ->
    # :success, :error -> :error) and falling back to :info for anything
    # else. Auto-called near the top of #app-container when chrome: true
    # (see #rebuild_with_state); apps with chrome: false place it explicitly.
    def flash_messages
      return unless (f = @_state[:_flash]) && !f.empty?
      f.each do |key, message|
        variant = case key.to_sym
                  when :notice then :success
                  when :error  then :error
                  else :info
                  end
        alert(variant: variant) { text message }
      end
    end

    def canvas_continue(message: "Processing...")
      components << Components::CanvasContinue.new(message: message)
    end

    def theme_switcher(position: :inline, show_label: true, **options)
      components << Components::ThemeSwitcher.new(position: position, show_label: show_label, **options)
    end

    # =========================================
    # Design Deck DSL methods (T7)
    # =========================================

    # Create a design deck with slide-based option selection.
    # The deck wraps its slides in a SlideContainer with :swap mode.
    #
    # @param title [String] Deck title
    # @param options [Hash] Additional options
    # @yield Block containing slide definitions
    # @return [Components::Deck::DesignDeck] The deck component
    #
    # @example
    #   design_deck "Architecture Direction" do
    #     slide "arch", "System Architecture" do
    #       option "Monolith" do
    #         code_block "...", lang: "ts"
    #       end
    #     end
    #   end
    def design_deck(title, **options, &block)
      deck = Components::Deck::DesignDeck.new(title, **options)
      components << deck
      render_state.current_deck = deck

      parent_components = components
      self.components = []
      evaluate_dsl_block(block)
      deck.children = components
      self.components = parent_components

      deck.validate!

      # Auto-append DeckSummary as the last slide (T9)
      slides = deck.children.select { |c| c.is_a?(Components::Deck::DeckSlide) }
      summary = Components::Deck::DeckSummary.new
      summary.deck_slides = slides
      deck.children << summary

      render_state.current_deck = nil
      deck
    end

    # Override slide to create DeckSlide when inside a design_deck context.
    # Falls through to DisplayDSL#slide when not in deck context.
    def slide(id, title = nil, **options, &block)
      unless render_state.current_deck
        return super(id, title, **options, &block)
      end

      deck_slide = Components::Deck::DeckSlide.new(id, title, **options)
      components << deck_slide
      render_state.current_slide = deck_slide

      parent_components = components
      self.components = []
      evaluate_dsl_block(block)
      deck_slide.children = components
      self.components = parent_components

      render_state.current_slide = nil
      deck_slide
    end

    # Create an option card within a DeckSlide.
    # Must be called inside a slide block within a design_deck.
    #
    # @param label [String] Option label
    # @param aside [String, nil] Aside text below preview
    # @param recommended [Boolean] Show "Recommended" badge
    # @param description [String, nil] Description for tooltip/aria
    # @param options [Hash] Additional options
    # @yield Block containing preview content (mermaid, code_block, etc.)
    #
    # @example
    #   option "Monolith", aside: "Simple", recommended: true do
    #     mermaid "graph TD; A-->B", compact: true
    #   end
    def option(label, **options, &block)
      raise "option must be inside a slide within design_deck" unless render_state.current_deck && render_state.current_slide

      opt = Components::Deck::DeckOption.new(label, **options)
      # Track parent slide context for selection state (T8)
      opt.slide_id = render_state.current_slide.id
      # Count options already in the current build's components list (not slide.children which isn't set yet)
      opt.option_index = components.count { |c| c.is_a?(Components::Deck::DeckOption) }
      components << opt

      parent_components = components
      self.components = []
      evaluate_dsl_block(block)
      opt.children = components
      self.components = parent_components

      opt
    end

    # =========================================
    # Deck Polish DSL methods (T14)
    # =========================================

    # Create an AI model picker for generate-more.
    # Hidden when fewer than 2 models are provided.
    #
    # @param models [Array<Hash>] Array of { id:, name:, provider: } hashes
    # @param default_model [String, nil] ID of the default selected model
    #
    # @example
    #   model_selector(
    #     models: [
    #       { id: "claude-3", name: "Claude 3 Opus", provider: "Anthropic" },
    #       { id: "gpt-4", name: "GPT-4", provider: "OpenAI" }
    #     ],
    #     default_model: "claude-3"
    #   )
    def model_selector(models:, default_model: nil, **options)
      components << Components::Deck::ModelSelector.new(
        models: models, default_model: default_model, **options
      )
    end

    # Show a fixed top confirmation bar with confirm/cancel buttons.
    # Slides down from top with optional auto-hide timer.
    #
    # @param message [String] Confirmation message
    # @param confirm_label [String] Label for confirm action (default: "Cancel")
    # @param cancel_label [String] Label for dismiss action (default: "Keep Going")
    # @param auto_hide [Integer, nil] Auto-hide after N seconds (default: 5)
    #
    # @example
    #   confirmation_bar(
    #     message: "Are you sure you want to cancel?",
    #     confirm_label: "Yes, Cancel",
    #     cancel_label: "Keep Going"
    #   )
    def confirmation_bar(message:, confirm_label: "Cancel", cancel_label: "Keep Going",
                         auto_hide: 5, **options)
      components << Components::Deck::ConfirmationBar.new(
        message: message, confirm_label: confirm_label,
        cancel_label: cancel_label, auto_hide: auto_hide, **options
      )
    end

    # Show a full-screen overlay after submit or cancel.
    # Displays status message with blur backdrop and optional auto-close tab.
    #
    # @param status [Symbol] Status type (:submitted or :cancelled)
    # @param message [String] Status message
    # @param auto_close_delay [Integer] Auto-close tab delay in ms (default: 800)
    #
    # @example
    #   close_overlay(status: :submitted, message: "Deck submitted!")
    def close_overlay(status:, message:, auto_close_delay: 800, **options)
      components << Components::Deck::CloseOverlay.new(
        status: status, message: message,
        auto_close_delay: auto_close_delay, **options
      )
    end

    # =========================================
    # Streaming DSL (server-push via SSE)
    # =========================================

    def stream(&block)
      @stream_block ||= block
    end

    def every(seconds, &block)
      return if @timers_frozen
      @timers << { interval: seconds, block: block, last_run: nil }
    end

    def has_timers?
      @timers.any?
    end

    # Set favicon — accepts a URL string or a single emoji character
    # Emoji example: favicon "🔥"
    # URL example: favicon "https://example.com/icon.png"
    def favicon(value)
      @favicon_value = value
    end

    # Returns the favicon as an href suitable for <link rel="icon">
    # Converts emoji to SVG data URI, file paths to base64 data URI; passes URLs through unchanged
    def favicon_href
      return nil unless @favicon_value
      @_favicon_href_cache ||= build_favicon_href
    end

    FAVICON_MIME_TYPES = {
      'ico' => 'image/x-icon', 'png' => 'image/png', 'svg' => 'image/svg+xml',
      'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'gif' => 'image/gif', 'webp' => 'image/webp'
    }.freeze

    # Serves a local file (stylesheet, image, ...) via the /sw-asset/ route
    # -- content-type by extension, ETag, and path-traversal-safe: the
    # resolved path must be under this app's own script directory or one of
    # its assets_dirs: (stream_weaver-1lo). Generalizes the local-path
    # detection favicon already did one-off (build_favicon_href) to any
    # asset, and to a real served/cacheable route instead of a base64 data
    # URI (so a large stylesheet doesn't bloat every page load).
    #
    # @param path [String] Absolute path, or relative to the calling script's directory
    # @return [String] URL to serve the file, e.g. "/sw-asset/<key>/name.css"
    # @raise [ArgumentError] if the file doesn't exist, or resolves outside the allowed directories
    def local_asset(path)
      abs_path = resolve_asset_path(path)
      raise ArgumentError, "local_asset: file not found: #{path}" unless abs_path

      ensure_asset_path_allowed!(abs_path, path)
      "/sw-asset/#{ComponentAssets.register_file(abs_path)}/#{File.basename(abs_path)}"
    end

    # Adds CSS as an inline <style> block, usable inside the DSL body itself
    # (unlike `stylesheets:`, which is only an App.new kwarg) -- so a single
    # shared-DSL file can carry its own re-skin whether it's require'd
    # standalone or instance_eval'd by canvas-push (stream_weaver-9uk).
    # Canvas has no route to serve a referenced asset file across processes
    # the way local_asset/stylesheets: do, so inlining the raw CSS text is
    # the one mechanism that works in both contexts.
    #
    # @param source [String] a local path (resolved relative to the calling
    #   script's directory, same rule as stylesheets:) or literal CSS text
    #   if it doesn't resolve to a file
    def use_stylesheet(source)
      css = resolve_stylesheet_content(source)
      @inline_stylesheets << css unless @inline_stylesheets.include?(css)
    end

    # In-DSL equivalents of App.new's `theme:`/`layout:` kwargs, for the same
    # reason use_stylesheet exists: a DSL file that gets instance_eval'd by
    # canvas-push/canvas-read never runs its own App.new, so a `theme:` kwarg
    # is simply not reachable in that path (stream_weaver-csf). Declaring
    # `use_theme :doc` in the DSL body makes the doc carry its own theme
    # everywhere it's rendered.
    #
    # These are new methods, NOT redefinitions of the `theme`/`layout`
    # attr_readers -- views.rb reads `app.theme`/`app.layout` in many places.
    def use_theme(name)
      @theme = validate_theme(name)
    end

    # Caveat: canvas-read renders through Views::AppContentView, which does
    # not evaluate exclusive-layout render blocks or layout slots (those are
    # AppView-only). So in the reader `use_layout` only reaches body-class /
    # CSS-selector level layout, not full exclusive-layout fidelity.
    def use_layout(name)
      @layout = name.to_sym
    end

    # =========================================
    # Layout components (Cabinet Control style)
    # =========================================

    def app_shell(sidebar_width: "320px", sidebar_position: :right, gap: "1.5rem", **options, &block)
      component = Components::AppShell.new(
        sidebar_width: sidebar_width,
        sidebar_position: sidebar_position,
        gap: gap,
        **options
      )
      components << component

      return component unless block

      render_state.current_app_shell = component
      evaluate_dsl_block(block)
      render_state.current_app_shell = nil

      component
    end

    def main(**options, &block)
      raise "main can only be used inside an app_shell block" unless render_state.current_app_shell

      parent_components = components
      self.components = []
      evaluate_dsl_block(block)
      render_state.current_app_shell.main_children = components
      self.components = parent_components
    end

    def sidebar(header: nil, sticky: true, **options, &block)
      raise "sidebar can only be used inside an app_shell block" unless render_state.current_app_shell

      sidebar_component = Components::Sidebar.new(header: header, sticky: sticky, **options)

      parent_components = components
      self.components = []
      evaluate_dsl_block(block)
      sidebar_component.children = components
      self.components = parent_components

      render_state.current_app_shell.sidebar_children << sidebar_component
    end

    def expandable_card(key:, title:, subtitle: nil, badge_text: nil, badge_variant: :default,
                        status: nil, initially_expanded: false, **options, &block)
      @_state[key] ||= initially_expanded

      component = Components::ExpandableCard.new(
        key: key, title: title, subtitle: subtitle,
        badge_text: badge_text, badge_variant: badge_variant,
        status: status, initially_expanded: initially_expanded,
        **options
      )
      with_container(component, &block)
    end

    private

    def build_favicon_href
      v = @favicon_value
      if v.match?(/\A\p{Emoji_Presentation}\z/) || v.match?(/\A[\p{So}\p{Sk}]\z/)
        "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>#{v}</text></svg>"
      elsif File.exist?(v)
        require 'base64'
        mime = FAVICON_MIME_TYPES[File.extname(v).delete('.').downcase] || 'image/png'
        "data:#{mime};base64,#{Base64.strict_encode64(File.binread(v))}"
      else
        v
      end
    end

    # Resolves a `stylesheets:` entry: a local file (relative to the script
    # dir, or absolute) becomes a served /sw-asset/ URL; anything else
    # (a real URL, or a string that just doesn't resolve to a local file)
    # passes through unchanged, same as always. Unlike local_asset, a
    # missing file is not an error here -- most stylesheets: entries are
    # ordinary hrefs, not local paths, so a non-match must stay silent.
    # A real local file outside the allowed directories still raises,
    # though -- that IS the traversal case this feature guards against.
    def resolve_stylesheet_href(href)
      abs_path = resolve_asset_path(href)
      return href unless abs_path

      ensure_asset_path_allowed!(abs_path, href)
      "/sw-asset/#{ComponentAssets.register_file(abs_path)}/#{File.basename(abs_path)}"
    end

    # Resolves a `use_stylesheet` argument to raw CSS text: a local file
    # (same resolution/traversal rules as stylesheets:) is read and its
    # content returned; anything else is treated as literal CSS. A source
    # containing a newline is assumed to already be CSS text and skips file
    # resolution entirely -- avoids stat-ing a multi-KB string as a path.
    def resolve_stylesheet_content(source)
      return source unless source.is_a?(String)
      return source if source.include?("\n")

      abs_path = resolve_asset_path(source)
      return source unless abs_path

      ensure_asset_path_allowed!(abs_path, source)
      File.read(abs_path)
    end

    # @return [String, nil] absolute path if `path` resolves to a real local
    #   file (as given, or relative to the script dir); nil for a URL or
    #   anything that doesn't exist on disk
    def resolve_asset_path(path)
      return nil if path.to_s.match?(%r{\A[a-z][a-z0-9+.\-]*://}i)

      [path, File.expand_path(path, @script_dir)].each do |candidate|
        expanded = File.expand_path(candidate)
        return expanded if File.exist?(expanded)
      end
      nil
    end

    def ensure_asset_path_allowed!(abs_path, original)
      return if @allowed_asset_dirs.any? { |dir| abs_path == dir || abs_path.start_with?("#{dir}/") }

      raise ArgumentError, "local_asset: #{original} resolves outside the app's script directory " \
                            "(#{@script_dir}) or its assets_dirs: -- pass assets_dirs: [...] to App.new to allow it"
    end

    # Captures children then appends the component (for item, column patterns)
    def capture_children_then_append(component, &block)
      parent_components = components
      self.components = []
      evaluate_dsl_block(block)
      component.children = components
      self.components = parent_components
      components << component
    end

    # Initialize state for form fields, handling form/scope context
    def initialize_form_state(key, options, default_value, skip_if_exists: false)
      if render_state.form_context
        options[:form_context] = render_state.form_context
      elsif render_state.current_scope
        # A field inside a bare `scope` block (not a `form` block, e.g. a
        # retained filter panel) -- FAC-P3.1 handoff: the adapter needs to
        # know this so it can render a scope-nested name/x-model path instead
        # of a flat one, the same way :form_context already does for forms.
        options[:scope_name] = render_state.current_scope
      end

      target_scope = render_state.form_context&.fetch(:name, nil) || render_state.current_scope
      if target_scope
        @_state[target_scope] ||= {}
        target = @_state[target_scope]
      else
        target = @_state
      end

      if skip_if_exists
        target[key] = default_value unless target.key?(key)
      else
        target[key] ||= default_value
      end
    end

    # form_for submit pipeline: symbolize -> coerce -> validate -> persist ->
    # flash + PRG transition (form-for.md §3-§5). A validation failure never
    # flashes/redirects -- it just populates errors_key so the same-request
    # re-render shows the summary Alert with the user's in-progress values
    # still in the scope (untouched here on the failure path).
    def form_for_submit(fields:, raw_values:, store:, record:, is_update:, errors_key:, defn:,
                         on_success:, validate_proc:, singular:)
      form_values = raw_values.transform_keys(&:to_sym)
      coerced, errors = form_for_coerce(fields, form_values)

      if validate_proc
        (instance_exec(coerced, &validate_proc) || {}).each do |field, msgs|
          (errors[field.to_sym] ||= []).concat(Array(msgs))
        end
      end

      if errors.any?
        state[errors_key] = errors
        return
      end
      state[errors_key] = nil

      if is_update
        store.update(record[:id], coerced)
        id = record[:id]
      else
        id = store.create(coerced)
      end

      flash[:notice] = "#{singular.capitalize} #{is_update ? 'updated' : 'created'}."

      if on_success
        instance_exec(id, &on_success)
      elsif defn
        sk = Resource::StateKeys
        state[sk::RESOURCE] = defn.name
        if defn.only.include?(:show)
          state[sk::ACTION] = :show
          state[sk::ID]     = id
        else
          state[sk::ACTION] = :index
        end
      end
    end

    def form_for_coerce(fields, form_values)
      errors  = {}
      coerced = {}
      fields.each do |f|
        key = f.name
        raw = form_values[key]
        coerced[key] = case f.type
        when :integer then form_for_number(raw, key, errors, :integer, "must be a whole number")
        when :number   then form_for_number(raw, key, errors, :number, "must be a number")
        else raw
        end
      end
      [coerced, errors]
    end

    def form_for_number(raw, key, errors, kind, message)
      return nil if raw.nil? || raw == ""
      kind == :integer ? Integer(raw) : Float(raw)
    rescue ArgumentError, TypeError
      (errors[key] ||= []) << message
      raw
    end

    # Internal, flat, unscoped state key (like _sw_resource/_sw_action/_sw_id)
    # that snapshots each non-retained scope's owning discriminant values, so
    # #apply_scope_lifecycle can detect a change between rebuilds. Not scoped
    # data itself -- routing/lifecycle metadata (FAC-P3.0a §8).
    SCOPE_WATCH_KEY = :_sw_scope_watch

    def register_scope(name, kind:, retain:)
      return @scope_registry[name] if @scope_registry.key?(name)

      existing_value = @_state[name]
      if @_state.key?(name) && !existing_value.is_a?(Hash)
        raise ArgumentError, "scope #{name.inspect} collides with an existing top-level state " \
                              "key holding a #{existing_value.class} -- scopes are always Hash sub-states"
      end

      @scope_registry[name] = { kind: kind, retain: retain }
    end

    # Owning routing discriminant per scope kind (FAC-P3.0a §4). :app-kind
    # (and any unrecognized kind) has no discriminant -- it never auto-resets.
    def discriminant_keys_for(kind)
      sk = Resource::StateKeys
      case kind
      when :resource then [sk::RESOURCE, sk::ID]
      when :form     then [sk::RESOURCE, sk::ACTION]
      when :fragment then [sk::RESOURCE, sk::ACTION, sk::ID, @route_key].compact
      end
    end

    # Clears each non-retained scope's sub-hash when its owning routing
    # discriminant changed since the last rebuild (FAC-P3.0a §4) -- the
    # framework-enforced replacement for hand-nulled edit_* keys at every
    # navigation-away call site. Runs before the DSL block evaluates so
    # stale values are gone before any field re-initializes its default.
    def apply_scope_lifecycle
      return if @scope_registry.empty?

      watch = @_state[SCOPE_WATCH_KEY] ||= {}
      @scope_registry.each do |name, meta|
        next if meta[:retain]
        keys = discriminant_keys_for(meta[:kind])
        next unless keys

        signature = keys.map { |k| @_state[k] }
        @_state[name] = {} if watch.key?(name) && watch[name] != signature
        watch[name] = signature
      end
    end

    def reserved_endpoint_path?(path)
      RESERVED_ENDPOINT_EXACT.include?(path) ||
        RESERVED_ENDPOINT_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end

    # Ensures a component's key/id is a stable scalar -- never a positional
    # index or an arbitrary object's #inspect, which would silently break on
    # any collection reorder.
    def validate_scalar_key!(key, context:)
      return key if key.nil?
      unless key.is_a?(String) || key.is_a?(Symbol) || key.is_a?(Integer)
        raise ArgumentError, "#{context}: key: must be a String, Symbol, or Integer, got #{key.class}"
      end
      key
    end

    # Detects two interactive components resolving to the same id within a
    # single build (typically same-label buttons in a loop, sharing block
    # source_location). First occurrence keeps its id unchanged; each further
    # occurrence gets a stable "-dup-N" suffix so it remains independently
    # dispatchable (FAC-P0.1). Warns once per id per process, or raises if
    # strict_ids: true was passed to the App.
    def disambiguate_component_id(candidate_id, label:, source_loc:)
      occurrence = render_state.seen_component_ids[candidate_id]
      render_state.seen_component_ids[candidate_id] = occurrence + 1
      return candidate_id if occurrence.zero?

      loc = source_loc ? source_loc.join(':') : 'unknown location'
      message = "StreamWeaver: duplicate component id for \"#{label}\" at #{loc} " \
                "-- likely the same label/block in a loop. Pass a stable key:, e.g. " \
                "button(#{label.inspect}, key: item.id) { ... }, for distinct, order-independent ids."

      raise ArgumentError, message if @strict_ids

      unless @_warned_duplicate_ids.include?(candidate_id)
        @_warned_duplicate_ids << candidate_id
        warn "#{message} Auto-assigned a unique id for now."
      end

      "#{candidate_id}-dup-#{occurrence + 1}"
    end

    def define_path_helpers(defn)
      s, p = defn.singular, defn.plural
      define_singleton_method(:"#{p}_path")      { "/#{p}" }
      define_singleton_method(:"new_#{s}_path")  { "/#{p}/new" }
      define_singleton_method(:"#{s}_path")      { |rec| "/#{s}/#{CGI.escape(rec[:id].to_s)}" }
      define_singleton_method(:"edit_#{s}_path") { |rec| "/#{s}/#{CGI.escape(rec[:id].to_s)}/edit" }
    end

    # Parse a string with {term} markers into Phrase and Term components
    def parse_lesson_string(content, glossary)
      children = []
      parts = content.split(/(\{[^}]+\})/)

      parts.each do |part|
        if part.start_with?('{') && part.end_with?('}')
          term_key = part[1..-2]
          children << Components::Term.new(term_key)
        elsif !part.empty?
          children << Components::Phrase.new(part)
        end
      end

      children
    end
  end
end
