# frozen_string_literal: true

require 'phlex'

module StreamWeaver
  module Canvas
    # The "side" region of a live canvas page: the viewer's comments with their
    # state, the agent-presence line and the Send buttons. Rendered by the
    # bridge from the session's notes, so updating it costs the agent nothing.
    # Everything viewer-supplied goes through Phlex's escaping as text. The
    # composer textarea is deliberately not here: this markup is swapped
    # wholesale, and a swap must never eat a draft or focus.
    class NotesPanel < Phlex::HTML
      STATE_LABELS = {
        'queued' => 'Queued', 'sent' => 'Sent', 'seen' => 'Seen',
        'working' => 'Working', 'done' => 'Done'
      }.freeze

      def self.render(**kwargs)
        new(**kwargs).call
      end

      # @param notes [Array<Hash>] session notes, each with :id, :state, :text
      # @param agent_waiting [Boolean] a wait for this canvas is connected
      def initialize(session_name:, notes:, agent_waiting: false)
        @session_name = session_name
        @notes = notes
        @agent_waiting = agent_waiting
      end

      def view_template
        div(class: 'sw-notes-panel') do
          h2(class: 'sw-notes-title') { 'Comments' }
          p(class: 'sw-notes-presence', data: { sw_presence: @agent_waiting ? 'waiting' : 'none' }) do
            @agent_waiting ? 'Your agent is waiting' : 'No agent is listening'
          end
          unless @agent_waiting
            p(class: 'sw-notes-tell') do
              plain 'tell your agent: '
              code(class: 'sw-notes-copy', data: { sw_action: 'copy' }) { 'see my comments' }
            end
          end
          comments_list
          div(class: 'sw-notes-actions') do
            button(type: 'button', data: { sw_action: 'send' }, disabled: queued_count.zero?) { 'Send to Agent' }
            button(type: 'button', data: { sw_action: 'send-end' }, disabled: queued_count.zero?) { 'Send & End' }
          end
        end
      end

      private

      def queued_count
        @notes.count { |n| n[:state] == 'queued' }
      end

      def comments_list
        if @notes.empty?
          p(class: 'sw-notes-empty') { 'No comments yet' }
          return
        end
        ul(class: 'sw-notes-list') do
          @notes.each do |n|
            li(data: { sw_note: n[:id], sw_state: n[:state] }) do
              span(class: 'sw-notes-state') { STATE_LABELS.fetch(n[:state], n[:state].to_s) }
              plain ' '
              span(class: 'sw-notes-text') { n[:text].to_s }
            end
          end
        end
      end
    end
  end
end
