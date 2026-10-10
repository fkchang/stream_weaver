# frozen_string_literal: true

require_relative '../extensions'

module StreamWeaver
  module Canvas
    # Hands a canvas session's browser events to the extension its reply_to names.
    #
    # reply_to is an opaque "<extension id>:<payload>" string. StreamWeaver routes on the prefix and
    # never interprets the payload; the extension registered a canvas_event_sink under that id and
    # decides what a recipient is. This is how a form can message an agent without anything having
    # to stay connected to the bridge (it drops events nobody is listening for).
    #
    # Contract for callers (BridgeServer#forward_to_claude): call after delivery to connected
    # clients, never rescue around it, never wait on it. Nothing here can raise to the caller.
    #
    # Ordering: every event gets its own thread, so two quick events can reach a sink in either
    # order, and a slow sink can have several calls in flight. A sink that needs order or a
    # concurrency limit must serialize for itself (peerpressure's does, per canvas).
    module EventSinks
      # What a sink receives. `event` is the same message connected clients got
      # ({type: 'event', name:, event:, data: {...}}); `state` is a copy of the session's form state.
      Context = Struct.new(:name, :extension_id, :payload, :event, :state, :pusher, keyword_init: true) do
        # Re-renders the canvas with `dsl` (the same as `streamweaver canvas-push`).
        def push(dsl) = pusher.call(dsl)
      end

      module_function

      def dispatch(name:, reply_to:, message:, state:, pusher:, logger:)
        text = reply_to.to_s.strip
        return if text.empty?

        extension_id, payload = text.split(':', 2)
        sink = Extensions.canvas_event_sink_for(extension_id)
        unless sink
          logger.call("canvas #{name}: reply_to names extension #{extension_id.inspect}, which has no canvas_event_sink")
          return
        end

        context = Context.new(name: name, extension_id: extension_id, payload: payload.to_s, event: message,
                              state: state, pusher: pusher)
        Thread.new do
          sink.call(context)
        rescue StandardError, ScriptError => e
          logger.call("canvas #{name}: canvas_event_sink #{extension_id} raised #{e.class}: #{e.message}")
        end
        nil
      end
    end
  end
end
