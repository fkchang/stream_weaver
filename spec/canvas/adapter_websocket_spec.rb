# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamWeaver::Adapter::AlpineJS do
  describe 'websocket mode' do
    let(:adapter) { described_class.new(url_prefix: '/canvas/test', mode: :websocket) }
    let(:view) { instance_double(Phlex::HTML) }
    let(:state) { {} }

    describe '#initialize' do
      it 'accepts mode parameter' do
        expect(adapter.mode).to eq(:websocket)
      end

      it 'defaults to http mode' do
        default_adapter = described_class.new
        expect(default_adapter.mode).to eq(:http)
      end
    end

    describe '#websocket_mode?' do
      it 'returns true when mode is websocket' do
        expect(adapter.websocket_mode?).to be true
      end

      it 'returns false when mode is http' do
        http_adapter = described_class.new(mode: :http)
        expect(http_adapter.websocket_mode?).to be false
      end
    end

    describe '#render_button in websocket mode' do
      let(:button_id) { 'btn_submit_1' }
      let(:label) { 'Submit' }
      let(:options) { {} }

      it 'uses @click with sendEvent instead of hx-post' do
        expect(view).to receive(:button).with(
          hash_including('@click' => /sendEvent/)
        )

        adapter.render_button(view, button_id, label, options)
      end

      it 'does not include hx-post attribute' do
        expect(view).to receive(:button).with(
          hash_not_including('hx-post')
        )

        adapter.render_button(view, button_id, label, options)
      end

      it 'includes button id in sendEvent call' do
        expect(view).to receive(:button).with(
          hash_including('@click' => /btn_submit_1/)
        )

        adapter.render_button(view, button_id, label, options)
      end
    end

    describe '#render_radio_group in websocket mode' do
      let(:key) { :choice }
      let(:choices) { ['A', 'B', 'C'] }
      let(:options) { {} }

      before do
        allow(view).to receive(:div).and_yield
        allow(view).to receive(:label).and_yield
        allow(view).to receive(:input)
        allow(view).to receive(:span)
      end

      it 'uses @change with sendEvent instead of hx-post' do
        expect(view).to receive(:input).with(
          hash_including('@change' => /sendEvent/)
        ).at_least(:once)

        adapter.render_radio_group(view, key, choices, options, state)
      end
    end

    describe '#cdn_scripts in websocket mode' do
      it 'includes WebSocket initialization script' do
        scripts = adapter.cdn_scripts
        ws_script = scripts.find { |s| s.include?('WebSocket') }

        expect(ws_script).not_to be_nil
      end
    end

    describe '#container_attributes in websocket mode' do
      it 'includes WebSocket-related Alpine data' do
        attrs = adapter.container_attributes(state)

        expect(attrs['x-data']).to include('wsConnected')
      end
    end

    describe '#render_tabs' do
      let(:tabs) do
        component = StreamWeaver::Components::Tabs.new(:view)
        %w[Alpha Beta].each do |label|
          component.children << StreamWeaver::Components::Tab.new(label)
        end
        component
      end

      before do
        allow(view).to receive(:div).and_yield
        allow(view).to receive(:input)
      end

      context 'in websocket mode' do
        it 'omits the state-sync HTMX attributes on eager tab triggers' do
          expect(view).to receive(:button).with(
            hash_not_including('hx-post', 'hx-vals', 'hx-swap')
          ).twice

          adapter.render_tabs(view, tabs, state)
        end

        it 'keeps the Alpine attributes on eager tab triggers' do
          expect(view).to receive(:button).with(
            hash_including('@click' => 'activeTab = 0', ':class' => /sw-tab-active/)
          ).ordered
          expect(view).to receive(:button).with(
            hash_including('@click' => 'activeTab = 1')
          ).ordered

          adapter.render_tabs(view, tabs, state)
        end
      end

      context 'in http mode' do
        let(:http_adapter) { described_class.new }

        it 'still posts tab state to the server on eager tab triggers' do
          expect(view).to receive(:button).with(
            hash_including(
              'hx-post' => '/update',
              'hx-vals' => '{"view":0}',
              'hx-swap' => 'none'
            )
          ).ordered
          expect(view).to receive(:button).with(
            hash_including(
              'hx-post' => '/update',
              'hx-vals' => '{"view":1}',
              'hx-swap' => 'none'
            )
          ).ordered

          http_adapter.render_tabs(view, tabs, state)
        end
      end
    end
  end
end

RSpec::Matchers.define :hash_not_including do |*keys|
  match do |actual|
    keys.none? { |key| actual.key?(key) }
  end
end
