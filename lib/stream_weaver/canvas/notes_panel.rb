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
      def initialize(session_name:, notes:, agent_waiting: false, review_ended: false, doc_updated: false, summary: nil, annotate: false)
        @session_name = session_name
        @notes = notes
        @agent_waiting = agent_waiting
        @review_ended = review_ended
        @doc_updated = doc_updated
        @summary = summary
        @annotate = annotate
      end

      HINT = 'Send to Agent: send these and keep reviewing. Send & End: send these and tell the agent ' \
             'the review is over; this page stays open.'

      LEGEND = 'Dashed outline: hover preview. Solid outline: the selected comment\'s element.'

      # Header and Send buttons are pinned (flex column); only the body scrolls.
      def view_template
        div(class: 'sw-notes-panel') do
          div(class: 'sw-notes-head') do
            h2(class: 'sw-notes-title') { 'Comments' }
            button(type: 'button', class: 'sw-annotate-toggle', data: { sw_action: 'annotate-toggle' },
                   aria: { pressed: @annotate.to_s }) { @annotate ? 'Annotate: on' : 'Annotate: off' }
          end
          div(class: 'sw-notes-body') do
            p(class: 'sw-notes-presence', data: { sw_presence: @agent_waiting ? 'waiting' : 'none' }) do
              @agent_waiting ? 'Your agent is waiting' : 'No agent is listening'
            end
            unless @agent_waiting
              p(class: 'sw-notes-tell') do
                plain 'tell your agent: '
                code(class: 'sw-notes-copy', data: { sw_action: 'copy' }) { 'see my comments' }
              end
            end
            p(class: 'sw-notes-ended') { 'Review ended. A new comment starts a new review.' } if @review_ended
            p(class: 'sw-notes-updated') { 'Doc updated just now' } if @doc_updated
            p(class: 'sw-notes-summary') { "Agent: #{@summary}" } if @summary && !@summary.empty?
            p(class: 'sw-notes-count') { "#{queued_count} unsent" }
            comments_list
          end
          div(class: 'sw-notes-foot') do
            div(class: 'sw-notes-actions') do
              button(type: 'button', data: { sw_action: 'send' }, disabled: queued_count.zero?) { 'Send to Agent' }
              button(type: 'button', data: { sw_action: 'send-end' }) { 'Send & End' }
            end
            p(class: 'sw-notes-hint') { HINT }
            p(class: 'sw-notes-hint sw-notes-legend') { LEGEND }
          end
        end
      end

      private

      def queued_count
        @notes.count { |n| n[:state] == 'queued' }
      end

      # "td: Platform team" (tag or kind, then the start of the element text).
      def context_line(note)
        label = (note[:tag] || note[:kind]).to_s
        text = note[:element_text].to_s.strip[0, 40]
        [label, text].reject(&:empty?).join(': ')
      end

      def comments_list
        if @notes.empty?
          p(class: 'sw-notes-empty') { 'No comments yet' }
          return
        end
        ul(class: 'sw-notes-list') do
          @notes.each_with_index do |n, i|
            li(class: 'sw-card', tabindex: '0',
               data: { sw_note: n[:id], sw_state: n[:state], sw_kind: n[:kind].to_s,
                       sw_element_text: n[:element_text].to_s, sw_breadcrumb: n[:breadcrumb].to_s }) do
              div(class: 'sw-card-top') do
                span(class: 'sw-card-n') { (i + 1).to_s }
                span(class: 'sw-notes-state') { STATE_LABELS.fetch(n[:state], n[:state].to_s) }
                span(class: 'sw-notes-gone', hidden: true) { '(element changed)' }
              end
              div(class: 'sw-notes-text', data: { sw_action: 'goto' }) { n[:text].to_s }
              ctx = [context_line(n), n[:breadcrumb].to_s].reject(&:empty?).join(' | ')
              div(class: 'sw-notes-ctx') { ctx } unless ctx.empty?
              next unless n[:state] == 'queued'

              div(class: 'sw-card-actions') do
                button(type: 'button', class: 'sw-notes-edit', data: { sw_action: 'edit' }, title: 'Edit') { 'Edit' }
                button(type: 'button', class: 'sw-notes-remove', data: { sw_action: 'remove' }, title: 'Remove') { 'Remove' }
              end
            end
          end
        end
      end
    end
  end
end
