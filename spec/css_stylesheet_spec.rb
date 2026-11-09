# frozen_string_literal: true

require "open3"

# CSS.full_stylesheet used to regex-extract a heredoc out of views.rb that no
# longer existed, so every caller silently got the 429-byte minimal_css stub
# (disc-194). It now asks the generator the standalone page uses.
RSpec.describe StreamWeaver::CSS, 'framework stylesheet' do
  it 'is never the minimal stub' do
    expect(described_class.full_stylesheet).not_to eq(described_class.minimal_css)
    expect(described_class.full_stylesheet).to include('body.sw-theme-doc', 'body.sw-theme-ide')
  end

  describe '.base_stylesheet' do
    it 'is the full stylesheet for a builder that requires only stream_weaver/css (bin/build_extension)' do
      lib = File.expand_path('../lib', __dir__)
      out, status = Open3.capture2e(RbConfig.ruby, '-I', lib, '-e',
                                    'require "stream_weaver/css"; print StreamWeaver::CSS.base_stylesheet.bytesize')
      expect(status).to be_success, out
      expect(out.to_i).to eq(described_class.full_stylesheet.bytesize)
    end

    it 'falls back to the minimal token set where the view layer is not defined (compiled Opal)' do
      hide_const('StreamWeaver::Views::AppView')
      expect(described_class.base_stylesheet).to eq(described_class.minimal_css)
    end

    it 'raises any other failure instead of silently returning the stub' do
      allow(StreamWeaver::Views::AppView).to receive(:master_theme_css).and_raise(NoMethodError, 'broken')
      expect { described_class.base_stylesheet }.to raise_error(NoMethodError, 'broken')

      allow(StreamWeaver::Views::AppView).to receive(:master_theme_css).and_raise(ArgumentError, 'broken')
      expect { described_class.base_stylesheet }.to raise_error(ArgumentError, 'broken')
    end
  end
end
