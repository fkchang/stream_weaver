# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'net/http'
require 'stream_weaver/canvas/client'
require_relative '../support/env_helper'

# The bug: a canvas bridge spawned detached (the staleness heal's restart, or
# any launcher whose own env lacks LANG/LC_ALL/LC_CTYPE) boots with
# Encoding.default_external == US-ASCII. Every render_canvas_page call that
# interpolates multibyte content -- an em-dash, a checkmark, non-ASCII text
# in a pushed doc -- then raises Encoding::CompatibilityError and 500s.
#
# ENCODING_PREAMBLE + the `-E` flag on the bridge's spawn (client.rb) are the
# fix; this spec pins the preamble's own behavior in isolation (unit), the
# exact command start_bridge hands to Process.spawn (unit), and the real
# spawn path end to end (integration).
RSpec.describe 'Canvas bridge UTF-8 encoding defaults' do
  include EnvHelper

  # LC_CTYPE resolves ahead of LANG in POSIX locale lookup and some
  # terminals (Terminal.app with "set locale variables on startup") export
  # it independently of LANG/LC_ALL -- stripped here too so this reproduces
  # the bug on those machines, not just ones where LANG/LC_ALL alone decide
  # the locale.
  STRIPPED_LOCALE_ENV = { 'LANG' => nil, 'LC_ALL' => nil, 'LC_CTYPE' => nil }.freeze

  describe 'StreamWeaver::Canvas::Client::ENCODING_PREAMBLE' do
    # Runs the preamble in a throwaway subprocess with the locale env removed
    # from ITS env specifically -- not the spec process's -- so this proves
    # the preamble itself forces UTF-8, independent of whatever locale the
    # machine running the suite happens to have.
    it 'forces UTF-8 default_external/internal even with no locale env' do
      code = <<~RUBY
        #{StreamWeaver::Canvas::Client::ENCODING_PREAMBLE}
        puts "\#{Encoding.default_external}|\#{Encoding.default_internal.inspect}"
      RUBY

      out, err, status = Open3.capture3(STRIPPED_LOCALE_ENV, RbConfig.ruby, '-e', code)

      expect(status).to be_success, err
      expect(out.strip).to eq('UTF-8|nil')
    end
  end

  describe '.utf8_locale_env' do
    it 'defaults LANG/LC_ALL to a UTF-8 locale when the caller has none' do
      with_env('LANG' => nil, 'LC_ALL' => nil) do
        expect(StreamWeaver::Canvas::Client.utf8_locale_env)
          .to eq('LANG' => 'en_US.UTF-8', 'LC_ALL' => 'en_US.UTF-8')
      end
    end

    it "preserves the caller's own LANG/LC_ALL when already UTF-8" do
      with_env('LANG' => 'fr_FR.UTF-8', 'LC_ALL' => 'fr_FR.UTF-8') do
        expect(StreamWeaver::Canvas::Client.utf8_locale_env)
          .to eq('LANG' => 'fr_FR.UTF-8', 'LC_ALL' => 'fr_FR.UTF-8')
      end
    end

    # LANG=C is exactly the case this method exists to fix -- passing it
    # through unchanged would leave shelled-out tools (gist publishing's
    # `gh` calls) running non-UTF-8 despite the bridge itself having been
    # forced to UTF-8 by ENCODING_PREAMBLE/-E.
    it 'overrides a non-UTF-8 LANG/LC_ALL rather than preserving it' do
      with_env('LANG' => 'C', 'LC_ALL' => 'C') do
        expect(StreamWeaver::Canvas::Client.utf8_locale_env)
          .to eq('LANG' => 'en_US.UTF-8', 'LC_ALL' => 'en_US.UTF-8')
      end
    end
  end

  describe '.bridge_spawn_command' do
    # What start_bridge actually hands to Process.spawn -- asserted directly
    # so the -E flag (or the env hash) can't silently drop out of the real
    # spawn path while the isolated unit specs above stay green.
    it 'carries the UTF-8 locale env and -E UTF-8 ahead of the script file' do
      with_env('LANG' => 'C', 'LC_ALL' => 'C') do
        expect(StreamWeaver::Canvas::Client.bridge_spawn_command('/tmp/canvas_start.rb')).to eq(
          [
            { 'LANG' => 'en_US.UTF-8', 'LC_ALL' => 'en_US.UTF-8' },
            RbConfig.ruby, '-E', 'UTF-8', '/tmp/canvas_start.rb'
          ]
        )
      end
    end
  end

  # The real thing: spawn a bridge via the actual ensure_bridge_running path
  # with the locale env stripped from the spawning process's own env --
  # exactly what the auto-heal restart does when its parent lacks it -- and
  # confirm a page containing multibyte characters renders instead of 500ing.
  describe 'a bridge booted with no locale env in the spawning env', :aggregate_failures do
    let(:session_name) { 'utf8-boot-e2e' }

    around do |example|
      @dir = File.join('/tmp', "sw-utf8-e2e-#{Process.pid}-#{rand(100_000)}")
      FileUtils.mkdir_p(@dir)
      with_env(
        {
          'STREAMWEAVER_CANVAS_SOCKET' => File.join(@dir, 'c.sock'),
          'STREAMWEAVER_CANVAS_PID' => File.join(@dir, 'c.pid')
        }.merge(STRIPPED_LOCALE_ENV)
      ) do
        example.run
      ensure
        kill_bridge
      end
    ensure
      FileUtils.rm_rf(@dir)
    end

    def pid_file = File.join(@dir, 'c.pid')
    def log_file = File.join(@dir, 'canvas.log')
    def bridge_pid = File.read(pid_file)[/pid=(\d+)/, 1].to_i
    def bridge_port = File.read(pid_file)[/port=(\d+)/, 1].to_i

    def kill_bridge
      Process.kill('TERM', bridge_pid) if File.exist?(pid_file) && bridge_pid.positive?
    rescue SystemCallError, IOError
      nil
    end

    def wait_until(seconds = 20)
      deadline = Time.now + seconds
      until (result = yield) || Time.now > deadline
        sleep 0.1
      end
      result
    end

    it 'renders multibyte content instead of 500ing with Encoding::CompatibilityError' do
      StreamWeaver::Canvas::Client.ensure_bridge_running
      expect(wait_until { File.exist?(pid_file) && bridge_port.positive? }).to be_truthy

      StreamWeaver::Canvas::Client.send_message(
        StreamWeaver::Canvas::Protocol::Messages.create(session_name, layout: :fluid, theme: :default)
      )
      StreamWeaver::Canvas::Client.send_message(
        StreamWeaver::Canvas::Protocol::Messages.push(
          session_name, "header1 'em-dash — checkmark ✓ 日本語'", source_dir: nil
        )
      )

      response = Net::HTTP.get_response(URI("http://127.0.0.1:#{bridge_port}/canvas/#{session_name}"))

      log_on_failure = -> { File.exist?(log_file) ? File.read(log_file) : '(no canvas.log)' }
      expect(response).to be_a(Net::HTTPSuccess), log_on_failure
      # Net::HTTP hands back the raw bytes tagged ASCII-8BIT regardless of the
      # response's charset -- the page itself declares UTF-8 (meta charset +
      # this Content-Type header), so re-tag before comparing.
      expect(response.body.force_encoding('UTF-8')).to include("em-dash — checkmark ✓ 日本語"), log_on_failure
    end
  end
end
