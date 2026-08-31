# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'stream_weaver/canvas/gist_publisher'

# Every example here stubs Open3.capture3. Nothing in this file may spawn a
# real `gh`, and nothing may touch the network: the whole point of the module
# under test is that it writes to a URL a coworker opens, so an accidental
# live call from a spec run would publish real content.
RSpec.describe StreamWeaver::Canvas::GistPublisher do
  let(:dsl) do
    <<~DSL
      doc_header title: "Auth Flow", eyebrow: "design"
      md "Some prose."
    DSL
  end

  # Shape of a real `gh api /gists` response, trimmed to the fields the
  # publisher reads.
  def gh_response(id: 'abc123', revisions: 1)
    {
      'id' => id,
      'html_url' => "https://gist.github.com/someone/#{id}",
      'history' => Array.new(revisions) { |i| { 'version' => format('%040d', i) } }
    }.to_json
  end

  def ok_status
    instance_double(Process::Status, success?: true, exitstatus: 0)
  end

  def fail_status(code = 1)
    instance_double(Process::Status, success?: false, exitstatus: code)
  end

  # Records every capture3 invocation so examples can assert on exact argv.
  def stub_capture3(*results)
    calls = []
    queue = results.dup
    allow(Open3).to receive(:capture3) do |*argv, **opts|
      calls << { argv: argv, stdin: opts[:stdin_data] }
      queue.shift || raise('unexpected extra Open3.capture3 call')
    end
    calls
  end

  describe '.publish' do
    context 'on create (no existing_id)' do
      it 'issues exactly one POST /gists call with array argv and no shell string' do
        calls = stub_capture3([gh_response, '', ok_status])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(calls.length).to eq(1)
        expect(calls[0][:argv]).to eq(['gh', 'api', '-X', 'POST', '/gists', '--input', '-'])
        expect(result[:ok]).to be true
        expect(result[:action]).to eq('create')
      end

      it 'sends both the .org and .rb file under the same base name' do
        calls = stub_capture3([gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow', dsl: dsl)

        payload = JSON.parse(calls[0][:stdin])
        expect(payload['files'].keys).to contain_exactly('auth-flow.org', 'auth-flow.rb')
        expect(payload['files']['auth-flow.org']['content']).to include('#+STREAMWEAVER_DSL: 1')
        expect(payload['files']['auth-flow.rb']['content']).to include('doc_header')
      end

      it 'never sends a public key (secret gist by gh default)' do
        calls = stub_capture3([gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(JSON.parse(calls[0][:stdin])).not_to have_key('public')
      end

      it 'strips a typed .rb or .org extension when deriving the base name' do
        calls = stub_capture3([gh_response, '', ok_status], [gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow.rb', dsl: dsl)
        described_class.publish(name: 'auth-flow.org', dsl: dsl)

        expect(JSON.parse(calls[0][:stdin])['files'].keys)
          .to contain_exactly('auth-flow.org', 'auth-flow.rb')
        expect(JSON.parse(calls[1][:stdin])['files'].keys)
          .to contain_exactly('auth-flow.org', 'auth-flow.rb')
      end

      it 'prepends use_theme/use_layout to the .rb payload via DocStore.dsl_with_metadata' do
        calls = stub_capture3([gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow', dsl: dsl, theme: :doc, layout: :wide)

        rb = JSON.parse(calls[0][:stdin])['files']['auth-flow.rb']['content']
        expect(rb).to start_with("use_theme :doc\nuse_layout :wide\n")
      end

      it 'uses the org #+TITLE: as the gist description' do
        calls = stub_capture3([gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(JSON.parse(calls[0][:stdin])['description']).to eq('Auth Flow')
      end

      it 'falls back to the base name as description when the doc has no title' do
        calls = stub_capture3([gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow', dsl: 'md "no header here"')

        expect(JSON.parse(calls[0][:stdin])['description']).to eq('auth-flow')
      end

      it 'returns the id, url, revision count and org coverage' do
        stub_capture3([gh_response(id: 'deadbeef', revisions: 3), '', ok_status])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:id]).to eq('deadbeef')
        expect(result[:url]).to eq('https://gist.github.com/someone/deadbeef')
        expect(result[:revisions]).to eq(3)
        expect(result[:coverage]).to include(:total, :recognized)
      end
    end

    context 'on update (existing_id present)' do
      it 'issues exactly one PATCH /gists/<id> call with both files' do
        calls = stub_capture3([gh_response(revisions: 2), '', ok_status])

        result = described_class.publish(name: 'auth-flow', dsl: dsl, existing_id: 'abc123')

        expect(calls.length).to eq(1)
        expect(calls[0][:argv]).to eq(['gh', 'api', '-X', 'PATCH', '/gists/abc123', '--input', '-'])
        expect(JSON.parse(calls[0][:stdin])['files'].keys)
          .to contain_exactly('auth-flow.org', 'auth-flow.rb')
        expect(result[:action]).to eq('update')
        expect(result[:revisions]).to eq(2)
      end

      it 'never sends a public key on a PATCH (visibility is immutable)' do
        calls = stub_capture3([gh_response, '', ok_status])

        described_class.publish(name: 'auth-flow', dsl: dsl, existing_id: 'abc123')

        expect(JSON.parse(calls[0][:stdin])).not_to have_key('public')
      end

      it 'refuses an existing_id that is not a plain gist id, without shelling out' do
        calls = stub_capture3

        result = described_class.publish(name: 'auth-flow', dsl: dsl, existing_id: 'abc/../../x')

        expect(result[:ok]).to be false
        expect(calls).to be_empty
      end
    end

    context 'when the gist was deleted upstream (404 on update)' do
      it 'falls back to a create and signals that the stale id should be forgotten' do
        calls = stub_capture3(
          ['', 'gh: Not Found (HTTP 404)', fail_status(1)],
          [gh_response(id: 'newid'), '', ok_status]
        )

        result = described_class.publish(name: 'auth-flow', dsl: dsl, existing_id: 'gone123')

        expect(calls.map { |c| c[:argv] }).to eq(
          [
            ['gh', 'api', '-X', 'PATCH', '/gists/gone123', '--input', '-'],
            ['gh', 'api', '-X', 'POST', '/gists', '--input', '-']
          ]
        )
        expect(result[:ok]).to be true
        expect(result[:action]).to eq('create')
        expect(result[:id]).to eq('newid')
        expect(result[:forget_stale_id]).to eq('gone123')
      end

      it 'does not retry a 404 that came from a create' do
        calls = stub_capture3(['', 'gh: Not Found (HTTP 404)', fail_status(1)])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(calls.length).to eq(1)
        expect(result[:ok]).to be false
      end

      it 'reports the create failure when the fallback create also fails' do
        stub_capture3(
          ['', 'gh: Not Found (HTTP 404)', fail_status(1)],
          ['', 'gh: Bad credentials (HTTP 401)', fail_status(1)]
        )

        result = described_class.publish(name: 'auth-flow', dsl: dsl, existing_id: 'gone123')

        expect(result[:ok]).to be false
        expect(result[:error]).to include('gh auth login')
      end
    end

    context 'on a non-zero gh exit' do
      it 'returns {ok: false, error:} rather than raising' do
        stub_capture3(['', 'gh: Validation Failed (HTTP 422)', fail_status(1)])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:ok]).to be false
        expect(result[:error]).to include('422')
      end

      it 'maps an auth failure to copy naming gh auth login and the gist scope' do
        stub_capture3(['', 'gh: Bad credentials (HTTP 401)', fail_status(1)])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:ok]).to be false
        expect(result[:error]).to include('gh auth login')
        expect(result[:error]).to include('gist')
      end

      it 'maps a missing-scope failure to the same actionable copy' do
        stub_capture3(
          ['', 'gh: Resource not accessible by personal access token (HTTP 403)', fail_status(1)]
        )

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:error]).to include('gh auth login')
        expect(result[:error]).to include('gist')
      end

      it 'maps a not-logged-in failure to the same actionable copy' do
        stub_capture3(
          ['', 'gh: To get started with GitHub CLI, please run: gh auth login.', fail_status(1)]
        )

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:error]).to include('gist')
      end

      it 'falls back to a generic message when gh says nothing on stderr' do
        stub_capture3(['', '', fail_status(7)])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:ok]).to be false
        expect(result[:error]).to include('7')
      end
    end

    context 'on a stalled network call' do
      it 'wraps the shell-out in Timeout.timeout so a stall cannot hang the request thread' do
        stub_capture3([gh_response, '', ok_status])

        expect(Timeout).to receive(:timeout)
          .with(described_class::TIMEOUT_SECONDS).once.and_call_original

        described_class.publish(name: 'auth-flow', dsl: dsl)
      end

      it 'returns an error instead of propagating Timeout::Error' do
        allow(Open3).to receive(:capture3).and_raise(Timeout::Error)

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:ok]).to be false
        expect(result[:error]).to match(/tim(ed )?out/i)
      end
    end

    context 'on unparseable gh output' do
      it 'returns an error rather than raising a JSON::ParserError' do
        stub_capture3(['not json at all', '', ok_status])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:ok]).to be false
        expect(result[:error]).to be_a(String)
      end

      it 'returns an error for valid JSON that is not a gist object' do
        stub_capture3(['null', '', ok_status])

        result = described_class.publish(name: 'auth-flow', dsl: dsl)

        expect(result[:ok]).to be false
        expect(result[:error]).to include('unexpected gh response')
      end
    end

    context 'with an invalid doc name' do
      it 'lets DocStore ArgumentError propagate for the caller to map to a 422' do
        stub_capture3

        expect { described_class.publish(name: '../etc/passwd', dsl: dsl) }
          .to raise_error(ArgumentError, /invalid doc name/)
      end

      it 'does not shell out when the name is rejected' do
        calls = stub_capture3

        expect { described_class.publish(name: '', dsl: dsl) }.to raise_error(ArgumentError)
        expect(calls).to be_empty
      end
    end
  end

  describe '.gh_available?' do
    before { described_class.instance_variable_set(:@gh_available, nil) }
    after  { described_class.instance_variable_set(:@gh_available, nil) }

    it 'does a cheap presence check, not an auth check' do
      expect(described_class).to receive(:system)
        .with('gh', '--version', out: File::NULL, err: File::NULL)
        .once.and_return(true)

      expect(described_class.gh_available?).to be true
    end

    it 'is false when gh is not on PATH' do
      allow(described_class).to receive(:system).and_return(nil)

      expect(described_class.gh_available?).to be false
    end

    it 'memoizes the answer so repeated widget renders do not respawn gh' do
      expect(described_class).to receive(:system).once.and_return(true)

      3.times { described_class.gh_available? }
    end
  end
end
