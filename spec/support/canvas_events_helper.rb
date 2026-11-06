# frozen_string_literal: true

require 'json'

# Reads back the lifecycle events a spec wrote to its throwaway log
# (STREAMWEAVER_CANVAS_EVENTS) and restores the environment the bridge is
# handed at boot, so specs that exercise either stay independent.
module CanvasEventsHelper
  START_ENV = %w[SW_BRIDGE_START_CAUSE SW_BRIDGE_START_DETAIL SW_BRIDGE_START_CALLER].freeze

  def canvas_events
    path = ENV.fetch('STREAMWEAVER_CANVAS_EVENTS')
    File.exist?(path) ? File.readlines(path).map { |l| JSON.parse(l) } : []
  end

  def last_canvas_event(name)
    canvas_events.reverse.find { |e| e['event'] == name.to_s }
  end

  def self.included(base)
    base.after { START_ENV.each { |k| ENV.delete(k) } }
  end
end
