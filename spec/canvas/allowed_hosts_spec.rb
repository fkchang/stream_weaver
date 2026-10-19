# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'tmpdir'
require 'stream_weaver/canvas/bridge_server'
require 'stream_weaver/canvas/reader'

RSpec.describe StreamWeaver::Canvas::AllowedHosts do
  around do |ex|
    prev = ENV.values_at(described_class::ENV_KEY, described_class::FILE_ENV_KEY)
    Dir.mktmpdir do |dir|
      @hosts_file = File.join(dir, 'canvas_allowed_hosts')
      ENV[described_class::FILE_ENV_KEY] = @hosts_file
      ex.run
    end
  ensure
    ENV[described_class::ENV_KEY], ENV[described_class::FILE_ENV_KEY] = prev
  end

  let(:tailnet) { 'mac.tail1234.ts.net' }

  def set_hosts(value)
    ENV[described_class::ENV_KEY] = value
  end

  describe '.permitted?' do
    before { set_hosts(nil) }

    it 'allows loopback by default, with or without a port' do
      expect(described_class.permitted?('127.0.0.1:4700')).to be true
      expect(described_class.permitted?('localhost')).to be true
      expect(described_class.permitted?('[::1]:4700')).to be true
    end

    it 'refuses a foreign host by default' do
      expect(described_class.permitted?(tailnet)).to be false
      expect(described_class.permitted?('100.64.0.7:4700')).to be false
    end

    it 'allows a configured host, ignoring case and port' do
      set_hosts(" #{tailnet.upcase} , mac,100.64.0.7 ")
      expect(described_class.permitted?("#{tailnet}:8445")).to be true
      expect(described_class.permitted?('mac')).to be true
      expect(described_class.permitted?('100.64.0.7')).to be true
    end

    it 'still refuses a host that is not listed' do
      set_hosts(tailnet)
      expect(described_class.permitted?('evil.example.com')).to be false
      expect(described_class.permitted?("x.#{tailnet}")).to be false
    end

    it 'never allows an empty or missing Host, even with an empty entry configured' do
      set_hosts(',, ')
      expect(described_class.permitted?('')).to be false
      expect(described_class.permitted?(nil)).to be false
      expect(described_class.permitted?(':4700')).to be false
    end

    it 'reads hosts from the config file, skipping comments and blanks, and unions them with the env var' do
      File.write(@hosts_file, "# tailnet\nmac.tail1234.ts.net  # laptop\n\n100.64.0.7\n")
      set_hosts('mac')
      %w[mac.tail1234.ts.net 100.64.0.7 mac].each { |h| expect(described_class.permitted?(h)).to be(true), h }
      expect(described_class.permitted?('evil.example.com')).to be false
    end

    it 'normalizes configured entries written with a port or brackets' do
      set_hosts('Mac:8445,[fd7a::1]:4700')
      expect(described_class.permitted?('mac')).to be true
      expect(described_class.permitted?('[fd7a::1]')).to be true
    end

    it 'survives a config file with invalid bytes' do
      File.binwrite(@hosts_file, "mac\n\xFF\xFE\n")
      expect(described_class.permitted?('mac')).to be true
      expect(described_class.permitted?('127.0.0.1')).to be true
    end

    it 'ignores wildcard entries' do
      set_hosts('*,*.ts.net')
      expect(described_class.permitted?(tailnet)).to be false
      expect(described_class.configured).to be_empty
    end
  end

  describe 'the bridge, the reader and the helper agree' do
    include Rack::Test::Methods

    let(:bridge) do
      Class.new(StreamWeaver::Canvas::BridgeServer).tap do |klass|
        klass.bridge = StreamWeaver::Canvas::Bridge.new(port: 0)
      end
    end
    let(:reader) { StreamWeaver::Canvas::Reader }

    def status_for(klass, host)
      Rack::MockRequest.new(klass).get('/health', 'HTTP_HOST' => host).status
    end

    [nil, 'mac.tail1234.ts.net,100.64.0.7'].each do |setting|
      it "answers every host the same way (setting: #{setting.inspect})" do
        set_hosts(setting)
        %w[127.0.0.1:4700 localhost mac.tail1234.ts.net:8445 100.64.0.7 evil.example.com].each do |host|
          expected = described_class.permitted?(host) ? 200 : 403
          expect(status_for(bridge, host)).to eq(expected), "bridge, #{host}"
          expect(status_for(reader, host)).to eq(expected), "reader, #{host}"
        end
      end
    end

    it 'refuses a foreign Host by default and says why' do
      set_hosts(nil)
      response = Rack::MockRequest.new(bridge).get('/health', 'HTTP_HOST' => tailnet)
      expect(response.status).to eq(403)
      expect(response.body).to eq('Host not permitted')
    end

    it 'ignores X-Forwarded-Host when deciding' do
      set_hosts(nil)
      response = Rack::MockRequest.new(bridge).get('/health', 'HTTP_HOST' => 'evil.example.com',
                                                              'HTTP_X_FORWARDED_HOST' => 'localhost')
      expect(response.status).to eq(403)
    end

    it 'refuses a cross-site POST to the bridge even from an allowed host, but not a cross-site GET' do
      set_hosts(tailnet)
      post = Rack::MockRequest.new(bridge).post('/canvas/x/event', 'HTTP_HOST' => tailnet,
                                                                    'HTTP_SEC_FETCH_SITE' => 'cross-site', input: '{}')
      expect(post.status).to eq(403)
      get = Rack::MockRequest.new(bridge).get('/health', 'HTTP_HOST' => tailnet, 'HTTP_SEC_FETCH_SITE' => 'cross-site')
      expect(get.status).to eq(200)
    end

    it 'keeps the reader Sec-Fetch-Site check for an allowed host' do
      set_hosts(tailnet)
      response = Rack::MockRequest.new(reader).get('/health', 'HTTP_HOST' => tailnet,
                                                              'HTTP_SEC_FETCH_SITE' => 'cross-site')
      expect(response.status).to eq(403)
    end
  end
end
