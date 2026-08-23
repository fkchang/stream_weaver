# frozen_string_literal: true

require 'spec_helper'
require 'stream_weaver/canvas/reader'

# disc-095: canvas-read renders interactive controls that call sendEvent(), a
# function only defined by the canvas bridge's cdn_scripts -- which the reader
# deliberately omits. Clicking one self-disables the button and then throws a
# ReferenceError. The fix renders those controls honestly inert in the reader
# while leaving live-canvas markup untouched.
RSpec.describe 'reader inert controls' do
  def render(app, adapter, state = {})
    StreamWeaver::Views::AppContentView.new(app, state, adapter, false).call
  end

  def controls_app
    app = StreamWeaver::App.new('t')
    app.button 'Submit'
    app.radio_group :size, %w[S M]
    app
  end

  describe StreamWeaver::Adapter::AlpineJS do
    describe '#inert?' do
      it 'is false by default' do
        expect(described_class.new(mode: :websocket).inert?).to be false
      end

      it 'is true when constructed inert' do
        expect(described_class.new(mode: :websocket, inert: true).inert?).to be true
      end
    end

    context 'when websocket mode is inert' do
      let(:adapter) { described_class.new(url_prefix: '/canvas/reader', mode: :websocket, inert: true) }
      let(:html) { render(controls_app, adapter) }

      it 'never emits sendEvent' do
        expect(html).not_to include('sendEvent')
      end

      it 'renders the button disabled with an explanatory title' do
        expect(html).to include('<button')
        expect(html).to match(/<button[^>]*disabled/)
        expect(html).to match(/<button[^>]*title="Interactive on live canvas only"/)
      end

      it 'never self-disables the button on click' do
        expect(html).not_to include('$el.disabled=true')
      end

      it 'renders radio inputs disabled with an explanatory title' do
        expect(html).to match(/<input[^>]*type="radio"[^>]*disabled/)
        expect(html).to match(/<input[^>]*type="radio"[^>]*title="Interactive on live canvas only"/)
      end

      it 'never emits an @change handler on radio inputs' do
        expect(html).not_to include('@change')
      end
    end
  end

  # Criterion 6: live-canvas rendering (real bridge, sendEvent defined) is
  # byte-for-byte unchanged. Pinned as exact expected markup rather than a
  # "suite is green" hand-wave -- a golden string is the only thing that
  # actually catches an accidental change to live output.
  describe 'live canvas rendering is byte-for-byte unchanged' do
    let(:adapter) { StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', mode: :websocket) }
    let(:html) { render(controls_app, adapter) }

    it 'emits the unchanged live button markup' do
      expect(html).to include(
        '<button class="sw-button btn btn-primary" ' \
        "@click=\"$el.disabled=true; sendEvent('action', {button: 'btn_submit_1', state: getFormState()})\">" \
        'Submit</button>'
      )
    end

    it 'emits the unchanged live radio markup' do
      expect(html).to include(
        '<input type="radio" name="size" value="S" ' \
        'x-model="size" ' \
        "@change=\"sendEvent('change', {field: 'size', value: 'S', state: getFormState()})\">"
      )
    end

    it 'differs from the inert rendering' do
      inert = render(controls_app,
        StreamWeaver::Adapter::AlpineJS.new(url_prefix: '/canvas/abc', mode: :websocket, inert: true))
      expect(inert).not_to eq(html)
    end
  end

  describe StreamWeaver::Canvas::Reader do
    let(:html) { described_class.render_dsl("button 'Submit'\nradio_group :size, %w[S M]") }

    it 'renders reader docs with no undefined sendEvent call' do
      expect(html).not_to include('sendEvent')
    end

    it 'renders reader controls disabled' do
      expect(html).to match(/<button[^>]*disabled/)
      expect(html).to match(/<input[^>]*type="radio"[^>]*disabled/)
    end

    it 'never self-disables a reader control on click' do
      expect(html).not_to include('$el.disabled=true')
    end
  end
end
