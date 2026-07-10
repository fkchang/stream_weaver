# frozen_string_literal: true

require "cgi"
require "json"
require "fileutils"
require "rack/test"
require "tmpdir"

ENV["RACK_ENV"] ||= "test"
ENV["SW_SESSION_DIR"] ||= File.join(Dir.tmpdir, "stream-weaver-bench-sessions")
FileUtils.mkdir_p(ENV.fetch("SW_SESSION_DIR"))
require "stream_weaver"

module StreamWeaverBench
  PEOPLE = Array.new(50) do |index|
    id = index + 1
    { id: id, name: format("Person %02d", id), email: format("person%02d@example.test", id), touched: "2026-07-01" }
  end.freeze
  STORIES = Array.new(12) do |index|
    id = index + 1
    { id: id, title: format("Story %02d", id), column: %w[Ready Active Done][index % 3], notes: ["Seed note #{id}"] }
  end.freeze

  class Metrics
    attr_accessor :rebuilds, :callbacks

    def initialize = reset!
    def reset! = (@rebuilds = @callbacks = 0)
    def callback! = (@callbacks += 1)
  end

  module Instrumented
    attr_accessor :bench_metrics

    def rebuild_with_state(...)
      bench_metrics.rebuilds += 1 if bench_metrics
      super
    end
  end

  def self.instrument(app, metrics)
    app.singleton_class.prepend(Instrumented)
    app.bench_metrics = metrics
    app
  end

  def self.deep_copy(value) = Marshal.load(Marshal.dump(value))

  module Html
    module_function

    def action_path(body, label)
      tags = body.scan(/<button\b[^>]*>.*?<\/button>/m)
      tag = tags.find { |candidate| candidate.gsub(/<[^>]+>/, "").include?(label) }
      raise "button not found: #{label}" unless tag
      tag[%r{hx-post="([^"]+)"}, 1] || raise("action path missing for #{label}")
    end

    def fragment_token(body)
      encoded = body[/name="_sw_fragment" value="([^"]+)"/, 1]
      encoded && CGI.unescapeHTML(encoded)
    end

    def node_count(body) = body.scan(/<(?!\/|!|\?)[a-z][^>]*>/i).length
  end
end
