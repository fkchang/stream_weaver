# frozen_string_literal: true

module StreamWeaver
  # One page's assets, by owner and kind. framework_css is layered
  # (StreamWeaver::CSS::LAYER_NAME) and user_css is not, which is the whole
  # reason they are two buckets. `+` concatenates bucket by bucket and drops
  # repeats, so the framework, the theme, the layout, the components and the
  # app can each contribute one and be merged (PageShell.resolve).
  Assets = Data.define(:fonts, :stylesheets, :framework_css, :user_css, :scripts, :body_classes) do
    # Missing buckets are empty; a nil bucket is empty; repeats are dropped.
    def self.of(**buckets)
      new(**members.to_h { |bucket| [bucket, Array(buckets[bucket]).uniq] })
    end

    def +(other)
      self.class.new(**to_h { |bucket, entries| [bucket, (entries + other.public_send(bucket)).uniq] })
    end
  end
end
