# frozen_string_literal: true

module StreamWeaver
  module Canvas
    # The id of the one-shot marker element a poll response's swapped-in
    # html can carry to mean "land the viewer at the top of this page
    # instead of following its own near-bottom scroll" (round-9 UAT --
    # BridgeServer#polling_script is the consumer; University::Listener's
    # SCROLL_TOP_HINT_DSL, the producer, interpolates this same constant
    # rather than repeating the string).
    #
    # Deliberately its own file, with no other requires: the producer lives
    # in University::Listener, whose subprocess (`Listener.start!` spawns it
    # with `-r stream_weaver/university/listener` alone, never the full
    # `stream_weaver` entry point) breaks on bridge_server.rb's own
    # dependency chain (Sinatra, GistSaveHandler, the org writer's
    # Components lookup) if listener.rb requires that file just to read one
    # string. Both ends require this instead.
    SCROLL_TOP_HINT_ID = 'sw-scroll-top-hint'
  end
end
