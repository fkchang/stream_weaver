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
          scoped_response(before_state) || Views::AppContentView.new(app, state, adapter, agentic).call
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

    def scoped_response(before_state)
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
      Views::FragmentContentView.new(app, state, adapter, fragment, updates: extras, state_patch: patch).call
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

        state[key.to_sym] = coerce_param_value(value, state[key.to_sym])
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
      app.render_state.checkbox_keys.each do |key|
        state[key] = false unless params.key?(key.to_s) || params.key?(key)
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
