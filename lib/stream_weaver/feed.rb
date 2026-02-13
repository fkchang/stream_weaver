# frozen_string_literal: true

require 'net/http'
require 'uri'

module StreamWeaver
  # HTTP push client for sending targeted DOM updates to a running StreamWeaver app.
  # Accepts either raw HTML strings or component DSL blocks.
  #
  # @example Raw HTML
  #   feed = StreamWeaver.connect("Live Monitor")
  #   feed.replace("#clock", "<span>#{Time.now}</span>")
  #
  # @example Component DSL
  #   feed.replace("#metric-rps") do
  #     card { stat_display value: 3500, label: "REQ/SEC", color: :blue }
  #   end
  class Feed
    include Pushable

    attr_reader :url

    def initialize(url)
      @url = url
    end

    private

    def push_update(action:, target:, html:)
      uri = URI("#{@url}/stream/push")
      Net::HTTP.post_form(uri, target: target, action: action.to_s, html: html)
    end
  end
end
