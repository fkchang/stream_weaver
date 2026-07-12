# frozen_string_literal: true

module StreamWeaver
  class StaleActionDefinition < StandardError; end

  # Owns the state-to-response pipeline for every interactive request.
  #
  # Updates and events dispatch against descriptors/components retained from the
  # tree sent to the browser, so they need only the post-interaction rebuild.
  # Legacy block buttons and forms still need a discovery rebuild because their
  # executable closures are created while the DSL is evaluated. FAC-P1.3 named
  # actions will remove that discovery rebuild for buttons.
  class InteractionRunner
    ROUTE_PARAMS = %w[splat captures app_id button_id key form_name _sw_fragment].freeze

    def initialize(app:, state:, params:, interaction:, target: nil, adapter:, agentic: false,
                   persist:, prepare_state: nil, result_container: nil, auto_close: false,
                   action_manifest: nil, generation: "0", persist_manifest: nil,
                   response_headers: nil, state_version: 0, persist_state_version: nil)
      @app = app
      @state = state
      @params = params
      @interaction = interaction.to_sym
      @target = target
      @adapter = adapter
      @agentic = agentic
      @persist = persist
      @prepare_state = prepare_state
      @result_container = result_container
      @auto_close = auto_close
      @action_manifest = action_manifest || Set.new
      @generation = generation.to_s
      @persist_manifest = persist_manifest
      @response_headers = response_headers
      @state_version = state_version.to_i
      @persist_state_version = persist_state_version
    end

    def call
      app.with_render_lock do
        # For named actions (discovery_required? false below), this is still
        # the retained tree from the last rebuild -- i.e. exactly what's live
        # in the browser right now, before this interaction's mutation. Row
        # narrowing (#row_narrowing) diffs a table found in here against the
        # same table after the final rebuild to prove a mutation is row-local.
        components_before = app.components
        before_state = deep_copy(state)
        prepare_state&.call(state)
        prepare_form_state if interaction == :form
        app.rebuild_with_state(state, generation: generation, state_version: state_version) if discovery_required?

        unless interaction == :form
          sync_params_to_state
          handle_unchecked_checkboxes
        end

        dispatch
        persist.call(state)

        completion_response || begin
          app.rebuild_with_state(state, generation: generation, state_version: state_version)
          persist_manifest&.call(app.render_state.action_tokens)
          scoped_response(before_state, components_before) || Views::AppContentView.new(app, state, adapter, agentic).call
        end
      end
    end

    private

    attr_reader :app, :state, :params, :interaction, :target, :adapter, :agentic,
                :persist, :prepare_state, :result_container, :auto_close,
                :action_manifest, :generation, :persist_manifest

    def response_headers = @response_headers
    def state_version = @state_version
    def persist_state_version = @persist_state_version

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    rescue TypeError
      value.transform_values { |item| item.dup rescue item }
    end

    def scoped_response(before_state, components_before)
      scope = declared_scope
      if named_action? && !@named_action_authorized
        response_headers&.call("HX-Retarget" => "#app-container")
        return Views::AppContentView.new(app, state, adapter, agentic).call
      end
      if fragment_param_present? && !scope
        response_headers&.call("HX-Retarget" => "#app-container")
        return Views::AppContentView.new(app, state, adapter, agentic).call
      end
      return unless scope

      if app.route_key && before_state[app.route_key] != state[app.route_key]
        response_headers&.call("HX-Retarget" => "#app-container")
        return Views::AppContentView.new(app, state, adapter, agentic).call
      end

      fragment = find_fragment(app.components, scope[:fragment])
      unless fragment
        response_headers&.call("HX-Retarget" => "#app-container")
        return Views::AppContentView.new(app, state, adapter, agentic).call
      end

      extras = scope[:updates].filter_map { |name| find_fragment_by_name(app.components, name) }
      if extras.length != scope[:updates].length
        response_headers&.call("HX-Retarget" => "#app-container")
        return Views::AppContentView.new(app, state, adapter, agentic).call
      end

      version = state_version + 1
      persist_state_version&.call(version)
      patch = state_patch(before_state, state, version)

      # Row-granular table swaps (stream_weaver-95k). A named action's row
      # mutation can be narrowed whether the table it touched is the primary
      # target fragment *or* one of the declared `updates:` extras -- the
      # common shape is actually the latter (an "Add" button living in a
      # toolbar fragment, with `updates: :the_table_fragment`), so both are
      # analyzed independently and each narrows or falls back on its own.
      if named_action? && components_before
        primary_swap = row_swap_for(components_before, fragment)
        extra_swaps = extras.map { |extra| row_swap_for(components_before, extra) }
      end
      extra_swaps ||= []

      if primary_swap
        response_headers&.call(primary_swap_headers(primary_swap))
        return Views::RowSwapView.new(app, state, adapter, updates: extras, extra_swaps: extra_swaps,
                                       state_patch: patch, primary: primary_swap_proc(primary_swap)).call
      end

      Views::FragmentContentView.new(app, state, adapter, fragment, updates: extras, extra_swaps: extra_swaps,
                                      state_patch: patch).call
    end

    # Row-local proof for one fragment: does it contain exactly one table
    # with row identity, and does that table's row-id list before/after this
    # interaction's rebuild prove the mutation touched only one row? Same
    # ordered row keys (edit), pre-set minus exactly the actioned key
    # (delete), or pre-set plus one trailing key (create) -- anything else
    # (a sort, a filter, more than one table, unresolvable row keys) returns
    # nil, and the caller falls back to that fragment's full content, which
    # is always correct (point 4 of the design: narrowing is a size
    # optimization only, never a state-semantics change).
    #
    # @param components_before [Array<Components::Base>] The retained tree from before this
    #   interaction's mutation (see #call)
    # @param new_fragment [Components::Fragment] The post-mutation fragment (target or extra)
    # @return [Hash, nil] `{ kind:, table:, idx:, row_dom_id: }` (idx absent for :delete) or nil
    def row_swap_for(components_before, new_fragment)
      old_fragment = find_fragment(components_before, new_fragment.id)
      return nil unless old_fragment

      old_table = single_row_table(old_fragment.children)
      new_table = single_row_table(new_fragment.children)
      return nil unless old_table && new_table && old_table.dom_id == new_table.dom_id

      old_ids = old_table.table_options[:row_ids]
      new_ids = new_table.table_options[:row_ids]
      return nil if old_ids.empty? || new_ids.empty? || old_ids.any?(&:nil?) || new_ids.any?(&:nil?)

      action_key = decoded_action && decoded_action[:k]
      return nil if action_key.nil?

      if new_ids == old_ids
        idx = old_ids.index(action_key)
        return nil unless idx
        { kind: :edit, table: new_table, idx: idx, row_dom_id: "#{new_table.dom_id}-row-#{old_ids[idx]}" }
      elsif old_ids.length == new_ids.length + 1 && (old_ids - [action_key]) == new_ids
        { kind: :delete, table: old_table, row_dom_id: "#{old_table.dom_id}-row-#{action_key}" }
      elsif new_ids.length == old_ids.length + 1 && new_ids[0...-1] == old_ids
        { kind: :create, table: new_table, idx: new_ids.length - 1 }
      end
    end

    # The table a fragment's row-mutation could be narrowed against, or nil
    # if the fragment doesn't contain exactly one table with row identity --
    # more than one is ambiguous (which table did the action touch?), so it
    # falls back like everything else unproven (FAC-P2.1's `dom_id` is only
    # assigned to column-DSL tables with row identity in the first place).
    def single_row_table(children)
      tables = collect_tables(children)
      tables.length == 1 ? tables.first : nil
    end

    def collect_tables(children)
      children.each_with_object([]) do |component, found|
        found << component if component.is_a?(Components::Table) && component.dom_id
        found.concat(collect_tables(component.children)) if component.respond_to?(:children) && component.children
      end
    end

    def primary_swap_headers(swap)
      case swap[:kind]
      when :edit then { "HX-Retarget" => "##{swap[:row_dom_id]}", "HX-Reswap" => "outerHTML" }
      when :delete then { "HX-Retarget" => "##{swap[:row_dom_id]}", "HX-Reswap" => "delete" }
      when :create then { "HX-Retarget" => "##{swap[:table].dom_id} tbody", "HX-Reswap" => "beforeend" }
      end
    end

    def primary_swap_proc(swap)
      return nil if swap[:kind] == :delete

      table = swap[:table]
      idx = swap[:idx]
      ->(view) { adapter.render_table_row(view, table.resolved_rows[idx], idx, table.table_options, state, table.dom_id) }
    end

    def declared_scope
      payload = named_action? ? decoded_action : decoded_fragment_param
      return unless payload && payload[:f]
      { fragment: payload[:f].to_s, updates: Array(payload[:u]).map(&:to_s) }
    end

    def decoded_fragment_param
      token = params["_sw_fragment"] || params[:_sw_fragment]
      ActionToken.decode(token) if token
    rescue ActionToken::Invalid
      nil
    end

    def fragment_param_present?
      params.key?("_sw_fragment") || params.key?(:_sw_fragment)
    end

    def state_patch(before_state, after_state, version)
      set = after_state.each_with_object({}) do |(key, value), changed|
        changed[key.to_s] = value unless before_state.key?(key) && before_state[key] == value
      end
      deleted = before_state.keys.reject { |key| after_state.key?(key) }.map(&:to_s)
      { set: set, delete: deleted, version: version }
    end

    def find_fragment(components, id)
      find_recursive(components) { |component| component.is_a?(Components::Fragment) && component.id == id }
    end

    def find_fragment_by_name(components, name)
      find_recursive(components) { |component| component.is_a?(Components::Fragment) && component.name.to_s == name.to_s }
    end

    def discovery_required?
      (interaction == :action && !named_action?) || interaction == :form
    end

    def sync_params_to_state
      params.each do |key, value|
        next if ROUTE_PARAMS.include?(key.to_s)

        if value.is_a?(Hash)
          # A scope-nested "live" field (FAC-P3.1 handoff): Rack already
          # parsed the Rails-style `scope[field]=value` param into a nested
          # hash. Merge the one changed field into the scope's sub-hash --
          # never replace it wholesale, since a single live field's keyup
          # only posts that one key, not its siblings.
          scope_name = key.to_sym
          state[scope_name] ||= {}
          value.each { |k, v| state[scope_name][k.to_sym] = coerce_param_value(v, state[scope_name][k.to_sym]) }
        else
          state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
        end
      end
    end

    def coerce_param_value(value, current_value)
      case
      when value.is_a?(Array) then value
      when value == "on" || value == "true" then true
      when value == "false" then false
      when current_value.is_a?(Array) then Array(value)
      else value
      end
    end

    def handle_unchecked_checkboxes
      app.render_state.checkbox_keys.each do |scope_name, key|
        if scope_name
          nested = params[scope_name.to_s]
          next if nested.is_a?(Hash) && (nested.key?(key.to_s) || nested.key?(key))
          state[scope_name] ||= {}
          state[scope_name][key] = false
        else
          state[key] = false unless params.key?(key.to_s) || params.key?(key)
        end
      end
    end

    def prepare_form_state
      values = (params[target.to_s] || params[target.to_sym] || {}).each_with_object({}) do |(key, value), result|
        result[key.to_sym] = coerce_param_value(value, nil)
      end
      state[target.to_sym] = values
      @form_values = values
    end

    def dispatch
      case interaction
      when :update
        nil
      when :action
        if named_action?
          payload = decoded_action
          return unless payload
          return unless action_manifest.include?(ActionToken.fingerprint(target))
          raise StaleActionDefinition if payload[:d] != app.action_definition_digest || payload[:g].to_s != generation
          @named_action_authorized = true
          app.bind_dispatch_state(state)
          app.actions[payload[:a].to_sym]&.call(state, payload[:k])
        else
          find_button(app.components, target.to_s)&.execute(state)
        end
      when :event
        component = find_component(app.components, target.to_sym)
        return unless component

        value = state[target.to_sym]
        component.execute_on_change(state, value) if component.respond_to?(:execute_on_change)
        component.execute_on_blur(state, value) if component.respond_to?(:execute_on_blur)
      when :form
        find_form(app.components, target.to_sym)&.execute_submit(state, @form_values)
      else
        raise ArgumentError, "unknown interaction: #{interaction.inspect}"
      end
    end

    def named_action?
      target.to_s.include?(".")
    end

    def decoded_action
      @decoded_action ||= ActionToken.decode(target)
    rescue ActionToken::Invalid
      nil
    end

    def completion_response
      return unless agentic && state[:_result] && result_container

      filtered = {}
      collect_input_keys(app.components).each { |key| filtered[key] = state[key] if state.key?(key) }
      filtered[:_result] = state[:_result]
      result_container[:result] = filtered
      result_container[:ready] = true
      return unless auto_close

      <<~HTML
        <html><body>
          <h1>Done!</h1>
          <script>setTimeout(function(){ window.close(); }, 500);</script>
        </body></html>
      HTML
    end

    def find_button(components, id)
      find_recursive(components) do |component|
        (component.is_a?(Components::Button) || component.is_a?(Components::MenuItem)) && component.id == id
      end
    end

    def find_form(components, name)
      find_recursive(components) do |component|
        component.is_a?(Components::Form) && component.name == name
      end
    end

    def find_component(components, key)
      find_recursive(components) do |component|
        component.respond_to?(:key) && component.key == key
      end
    end

    def find_recursive(components, &match)
      components.each do |component|
        return component if match.call(component)

        if component.respond_to?(:children) && component.children
          found = find_recursive(component.children, &match)
          return found if found
        end
        if component.is_a?(Components::Modal) && component.footer_component&.children
          found = find_recursive(component.footer_component.children, &match)
          return found if found
        end
      end
      nil
    end

    def collect_input_keys(components)
      components.each_with_object([]) do |component, keys|
        keys << component.key if component.respond_to?(:key) && component.key
        keys.concat(collect_input_keys(component.children)) if component.respond_to?(:children) && component.children
      end
    end
  end
end
