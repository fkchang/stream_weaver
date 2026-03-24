# frozen_string_literal: true

module StreamWeaver
  # Shared interface for pushing targeted DOM updates.
  # Included by Feed (HTTP push) and Streamer (SSE broadcast).
  # Implementors provide `push_update(action:, target:, html:)`.
  module Pushable
    def replace(target, html = nil, state: nil, &block)
      html ||= render_components(state, &block) if block
      push_update(action: :replace, target: target, html: html)
    end

    def append(target, html = nil, state: nil, &block)
      html ||= render_components(state, &block) if block
      push_update(action: :append, target: target, html: html)
    end

    def prepend(target, html = nil, state: nil, &block)
      html ||= render_components(state, &block) if block
      push_update(action: :prepend, target: target, html: html)
    end

    def remove(target)
      push_update(action: :remove, target: target, html: "")
    end

    def add_class(target, class_name)
      push_update(action: :add_class, target: target, value: class_name)
    end

    def remove_class(target, class_name)
      push_update(action: :remove_class, target: target, value: class_name)
    end

    private

    def render_components(state = nil, &block)
      components = FeedBuilder.build(state, &block)
      ComponentRenderer.render_html(StreamWeaver.default_adapter, components)
    end
  end
end
