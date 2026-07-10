#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "benchmark"
require "fileutils"
require "optparse"
require_relative "fixtures/ledger"
require_relative "fixtures/warroom"
require_relative "baselines/ledger"
require_relative "baselines/warroom"

module StreamWeaverBench
  Sample = Data.define(:server_ms, :rack_ms, :response_bytes, :request_bytes, :rebuilds, :callbacks, :changed_nodes, :full_nodes)

  class Runner
    BASELINE_PATHS = {
      ledger: { create: "/create", edit: "/edit", validation: "/invalid", filter: "/filter", delete: "/delete" },
      warroom: { note_append: "/note", column_move: "/move" }
    }.freeze
    LABELS = { create: "Create", edit: "Edit", validation: "Invalid", delete: "Delete", note_append: "Append note", column_move: "Move story" }.freeze

    def initialize(iterations:, warmups:, write: true)
      @iterations = iterations
      @warmups = warmups
      @write = write
    end

    def run
      lines = ["# Phase-1 dispatch benchmark", "", "Rack end-to-end time is the in-process request duration; server time excludes Rack::Test response handling.", ""]
      run_fixture(:ledger, Fixtures::Ledger, Baselines::Ledger, lines)
      run_fixture(:warroom, Fixtures::Warroom, Baselines::Warroom, lines)
      report = lines.join("\n") + "\n"
      puts report
      write_report(report) if @write
      report
    end

    private

    def run_fixture(name, fixture, baseline, lines)
      fixture::INTERACTIONS.each do |interaction|
        baseline_samples = samples { measure_baseline(name, baseline, interaction) }
        baseline_bytes = median(baseline_samples.map(&:response_bytes))
        lines << "## #{name}: #{interaction}"
        lines << ""
        lines << "| variant | median server ms | p95 server ms | median rack ms | p95 rack ms | response bytes | request bytes | rebuilds | callbacks | changed nodes / full | vs-baseline ratio |"
        lines << "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
        append_row(lines, "phlex_baseline", baseline_samples, baseline_bytes)
        fixture::VARIANTS.each do |variant|
          measured = samples { measure_streamweaver(fixture, variant, interaction) }
          append_row(lines, variant, measured, baseline_bytes)
        end
        scoped_variants = fixture::VARIANTS.select { |variant| variant.to_s.include?("fragment") || variant == :update_filter }
        scoped_variants.each do |variant|
          measured = samples { measure_streamweaver(fixture, variant, interaction) }
          bytes = median(measured.map(&:response_bytes))
          lines << ""
          lines << "**#{bytes <= baseline_bytes * 1.20 ? 'PASS' : 'FAIL'}** — `#{variant}` response #{bytes} B <= 1.20 × baseline #{baseline_bytes} B (#{(baseline_bytes * 1.20).round(1)} B)."
        end
        lines << ""
      end
    end

    def samples
      @warmups.times { yield }
      Array.new(@iterations) { yield }
    end

    def measure_baseline(name, baseline, interaction)
      app, metrics = baseline.build
      session = Rack::Test::Session.new(Rack::MockSession.new(app))
      full_nodes = Html.node_count(session.get("/").body)
      params = interaction == :filter ? { query: "Person 01" } : {}
      path = BASELINE_PATHS.fetch(name).fetch(interaction)
      metrics.reset!
      response, rack_ms, server_ms = timed_request(session, path, params)
      Sample.new(server_ms:, rack_ms:, response_bytes: response.body.bytesize,
        request_bytes: Rack::Utils.build_nested_query(params).bytesize, rebuilds: 0,
        callbacks: metrics.callbacks, changed_nodes: Html.node_count(response.body), full_nodes: full_nodes)
    end

    def measure_streamweaver(fixture, variant, interaction)
      app, metrics = fixture.build(variant)
      session = Rack::Test::Session.new(Rack::MockSession.new(app))
      setup = session.get("/")
      full_nodes = Html.node_count(setup.body)
      params = {}
      path = if interaction == :filter
        params = { query: "Person 01" }
        if variant == :update_filter
          params[:_sw_fragment] = Html.fragment_token(setup.body) if Html.fragment_token(setup.body)
          "/event/query"
        else
          "/update"
        end
      else
        Html.action_path(setup.body, LABELS.fetch(interaction))
      end
      metrics.reset!
      response, rack_ms, server_ms = timed_request(session, path, params)
      raise "#{variant} #{interaction}: HTTP #{response.status}" unless response.ok?
      Sample.new(server_ms:, rack_ms:, response_bytes: response.body.bytesize,
        request_bytes: Rack::Utils.build_nested_query(params).bytesize, rebuilds: metrics.rebuilds,
        callbacks: metrics.callbacks, changed_nodes: Html.node_count(response.body), full_nodes: full_nodes)
    end

    def timed_request(session, path, params)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = nil
      server_started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response = session.post(path, params, "HTTP_HX_REQUEST" => "true")
      server_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - server_started) * 1000
      rack_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000
      [response, rack_ms, server_ms]
    end

    def append_row(lines, variant, values, baseline_bytes)
      response_bytes = median(values.map(&:response_bytes))
      lines << format("| %s | %.3f | %.3f | %.3f | %.3f | %d | %d | %d | %d | %d / %d | %.2f |",
        variant, median(values.map(&:server_ms)), percentile(values.map(&:server_ms), 0.95),
        median(values.map(&:rack_ms)), percentile(values.map(&:rack_ms), 0.95), response_bytes,
        median(values.map(&:request_bytes)), median(values.map(&:rebuilds)), median(values.map(&:callbacks)),
        median(values.map(&:changed_nodes)), median(values.map(&:full_nodes)), baseline_bytes.zero? ? Float::INFINITY : response_bytes.fdiv(baseline_bytes))
    end

    def median(values) = percentile(values, 0.50)
    def percentile(values, fraction) = values.sort.fetch([(values.length * fraction).ceil - 1, 0].max)
    def write_report(report)
      sha = `git rev-parse --short HEAD`.strip
      FileUtils.mkdir_p(File.expand_path("results", __dir__))
      File.write(File.expand_path("results/#{sha}.md", __dir__), report)
    end
  end
end

options = { iterations: 30, warmups: 5, write: true }
OptionParser.new do |parser|
  parser.on("--iterations N", Integer) { |value| options[:iterations] = value }
  parser.on("--warmups N", Integer) { |value| options[:warmups] = value }
  parser.on("--no-write") { options[:write] = false }
end.parse!
abort "iterations must be positive" unless options[:iterations].positive?
StreamWeaverBench::Runner.new(**options).run
