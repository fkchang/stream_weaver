# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/cli'
require 'stream_weaver/iterm'
require 'iterm2'
require_relative 'support/env_helper'

# Round-9 UAT: `streamweaver focus-me` is step 3's fix for a blocking
# standalone form (`run_once!`) that opens its own browser tab and pulls the
# user's attention there -- once that process exits, nothing else raises the
# worker's own tab back to front, so the reaction to its JSON prints into a
# pane nobody is looking at. Every course prompt calls this blind, so a
# missing or garbled ITERM_SESSION_ID (normal off a Mac, or outside iTerm2)
# must never raise -- it's called purely for its side effect.
RSpec.describe StreamWeaver::CLI do
  include EnvHelper

  describe '.focus_me' do
    let(:client) { instance_double(ITerm2::Client) }

    before do
      allow(StreamWeaver::ITerm).to receive(:available?).and_return(true)
      allow(ITerm2).to receive(:connect).and_yield(client)
      allow(client).to receive(:activate_session).and_return(true)
    end

    it 'activates the session id parsed out of a real ITERM_SESSION_ID' do
      with_env('ITERM_SESSION_ID' => 'w0t0p0:some-real-guid') do
        described_class.focus_me

        expect(client).to have_received(:activate_session).with('some-real-guid')
      end
    end

    # current_session_guid (iterm.rb) is what actually decides "no real
    # session id here" -- these three env shapes all resolve to nil there,
    # and NOTHING is stubbed between focus_me and that real parsing, so a
    # regression in either method fails this example for the right reason.
    it 'never connects to activate a session for a missing, empty, or garbled ITERM_SESSION_ID' do
      %w[missing empty garbled].each do |shape|
        value = { 'missing' => nil, 'empty' => '', 'garbled' => 'no-colon-here' }.fetch(shape)

        with_env('ITERM_SESSION_ID' => value) do
          expect { described_class.focus_me }.not_to raise_error, "raised for a #{shape} env value"
          expect(ITerm2).not_to have_received(:connect), "connected to iTerm2 for a #{shape} env value"
        end
      end
    end

    it 'is a silent no-op outside iTerm2, without raising' do
      allow(StreamWeaver::ITerm).to receive(:available?).and_return(false)

      with_env('ITERM_SESSION_ID' => 'w0t0p0:some-real-guid') do
        expect { described_class.focus_me }.not_to raise_error
        expect(ITerm2).not_to have_received(:connect)
      end
    end
  end
end
