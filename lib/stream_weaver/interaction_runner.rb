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
    ROUTE_PARAMS = %w[splat captures app_id button_id key form_name].freeze

    def initialize(app:, state:, params:, interaction:, target: nil, adapter:, agentic: false,
                   persist:, prepare_state: nil, result_container: nil, auto_close: false,
                   action_manifest: nil, generation: "0", persist_manifest: nil)
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
    end

    def call
      app.with_render_lock do
        prepare_state&.call(state)
        prepare_form_state if interaction == :form
        app.rebuild_with_state(state, generation: generation) if discovery_required?

        unless interaction == :form
          sync_params_to_state
          handle_unchecked_checkboxes
        end

        dispatch
        persist.call(state)

        completion_response || begin
          app.rebuild_with_state(state, generation: generation)
          persist_manifest&.call(app.render_state.action_tokens)
          Views::AppContentView.new(app, state, adapter, agentic).call
        end
      end
    end

    private

    attr_reader :app, :state, :params, :interaction, :target, :adapter, :agentic,
                :persist, :prepare_state, :result_container, :auto_close,
                :action_manifest, :generation, :persist_manifest

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
