# frozen_string_literal: true

require "org-ruby"
require_relative "../../lib/stream_weaver/org/writer"

RSpec.describe "org-ruby generic-renderer smoke test" do
  it "does not silently drop any callout/card/comparison content when rendered by a generic org viewer" do
    dsl = eval(File.read(File.join(__dir__, "../fixtures/org/sample_doc.rb"))) # rubocop:disable Security/Eval
    org = StreamWeaver::Org::Writer.from_dsl(dsl)

    quote_block_count = org.scan(/^#\+begin_quote$/).length
    html = Orgmode::Parser.new(org).to_html
    rendered_blockquote_count = html.scan(/<blockquote>/).length

    expect(rendered_blockquote_count).to eq(quote_block_count)
    expect(html).to include("Heads up") # callout title text actually present
    expect(html).to include("Pipeline") # card title text actually present
  end

  it "renders a Ruby-authored external link as a real link in a generic org viewer, not literal text" do
    # stream_weaver-043f: link conversion used to be scoped to internal
    # #anchor targets only, so a DSL-authored external link stayed as
    # literal markdown on export -- correct org syntax elsewhere, but not
    # something a generic org viewer (this gem, GitHub, markymark) renders
    # as clickable, since "[text](url)" isn't real org link syntax.
    dsl = <<~RUBY
      md "watch [5:54](https://example.com/watch?v=X&t=354s) for the setup"
    RUBY
    org = StreamWeaver::Org::Writer.from_dsl(dsl)

    html = Orgmode::Parser.new(org).to_html

    expect(html).to include(%(href="https://example.com/watch?v=X&amp;t=354s"))
  end
end
