# frozen_string_literal: true

require "stream_weaver/adapter/opal"
require "stream_weaver/opal/renderer"

# Adapter::Static exists so the server (AlpineJS) and the browser (Opal) render
# document components from one implementation instead of two that drift.
#
# These specs pin that down from both directions: the module is actually shared
# by both adapters, and rendering a component through each produces the same
# markup. Without the second half, someone can "fix" a doc component in
# alpinejs.rb and silently leave the browser build behind -- which is exactly
# the failure mode the extraction was meant to remove.
RSpec.describe StreamWeaver::Adapter::Static do
  SHARED_RENDERERS = %i[
    render_text
    render_callout
    render_comparison
    render_doc_header
    render_doc_section_header
    render_sidebar_toc
    render_code_block
  ].freeze

  # Seams the module deliberately leaves to the including adapter.
  HOOKS = %i[
    inject_component_css
    inject_sidebar_toc_assets
    inject_code_highlighting
    render_code_block_copy_button
  ].freeze

  describe "module composition" do
    it "is included by the server adapter" do
      expect(StreamWeaver::Adapter::AlpineJS.ancestors).to include(described_class)
    end

    it "is included by the browser adapter" do
      expect(StreamWeaver::Adapter::Opal.ancestors).to include(described_class)
    end

    it "defines every shared document renderer exactly once" do
      SHARED_RENDERERS.each do |m|
        expect(described_class.instance_methods).to include(m),
          "expected Static to own ##{m}"
      end
    end

    it "does not leave copies behind on the server adapter" do
      SHARED_RENDERERS.each do |m|
        owner = StreamWeaver::Adapter::AlpineJS.instance_method(m).owner
        expect(owner).to eq(described_class),
          "##{m} is still defined on #{owner} -- the browser build will not see changes to it"
      end
    end

    it "requires both adapters to supply the asset and behavior hooks" do
      [StreamWeaver::Adapter::AlpineJS, StreamWeaver::Adapter::Opal].each do |klass|
        HOOKS.each do |hook|
          expect(klass.instance_methods + klass.private_instance_methods).to include(hook),
            "#{klass} must implement ##{hook}"
        end
      end
    end
  end

  describe "cross-adapter markup parity" do
    let(:state) { {} }

    # The Opal adapter runs under MRI here: OpalRenderer is plain Ruby, and
    # Adapter::Opal#md_to_html has an MRI branch. So both paths are exercisable
    # in the normal suite, no browser required.
    def render_via_opal(component)
      adapter = StreamWeaver::Adapter::Opal.new
      view = StreamWeaver::Opal::OpalRenderer.new(adapter, state)
      view.define_singleton_method(:adapter) { adapter }
      component.render(view, state)
      view.to_html
    end

    def render_via_alpine(component)
      StreamWeaver::ComponentRenderer.render_html(
        StreamWeaver::Adapter::AlpineJS.new, [component], state
      )
    end

    # Alpine wraps components in the page shell and injects <style>/<script>
    # assets inline; Opal appends CSS to <head> instead. Neither is part of the
    # component's own markup, so compare the component element itself.
    def component_markup(html, selector_class)
      m = html.match(/<(\w+)[^>]*class="[^"]*#{Regexp.escape(selector_class)}[^"]*"/)
      raise "no element with class #{selector_class} in:\n#{html}" unless m

      tag = m[1]
      start = m.begin(0)
      depth = 0
      scanner = start
      while (nxt = html.index(/<\/?#{tag}[\s>]/, scanner))
        if html[nxt, 2] == "</"
          depth -= 1
          return html[start..(html.index(">", nxt))] if depth.zero?
        else
          depth += 1
        end
        scanner = nxt + 1
      end
      raise "unbalanced <#{tag}>"
    end

    it "renders a callout identically" do
      build = -> { StreamWeaver::Components::Callout.new(variant: :warning, title: "Heads up") }
      expect(component_markup(render_via_opal(build.call), "sw-callout"))
        .to eq(component_markup(render_via_alpine(build.call), "sw-callout"))
    end

    it "renders a doc_header identically" do
      build = lambda {
        StreamWeaver::Components::DocHeader.new(
          title: "Calendar-Driven Travel State",
          eyebrow: "ARIA · PERSONAL OS",
          pills: [{ text: "Draft" }, "June 25, 2026"]
        )
      }
      expect(component_markup(render_via_opal(build.call), "sw-doc-header"))
        .to eq(component_markup(render_via_alpine(build.call), "sw-doc-header"))
    end

    it "renders a doc_section_header identically" do
      build = -> { StreamWeaver::Components::DocSectionHeader.new("01", "Problem Statement", id: "problem") }
      expect(component_markup(render_via_opal(build.call), "sw-doc-section-header"))
        .to eq(component_markup(render_via_alpine(build.call), "sw-doc-section-header"))
    end

    it "renders a sidebar_toc identically" do
      build = lambda {
        StreamWeaver::Components::SidebarToc.new(
          sections: [{ id: "problem", label: "Problem Statement" },
                     { id: "arch", label: "Architecture" }]
        )
      }
      expect(component_markup(render_via_opal(build.call), "sw-sidebar-toc"))
        .to eq(component_markup(render_via_alpine(build.call), "sw-sidebar-toc"))
    end

    it "renders a code_block identically when no copy affordance is requested" do
      build = -> { StreamWeaver::Components::CodeBlock.new("puts 'hi'", lang: "ruby") }
      expect(component_markup(render_via_opal(build.call), "sw-code-block"))
        .to eq(component_markup(render_via_alpine(build.call), "sw-code-block"))
    end

    it "omits the copy button in the browser adapter, where it has no behavior" do
      build = -> { StreamWeaver::Components::CodeBlock.new("puts 'hi'", lang: "ruby", copy: true) }
      expect(render_via_alpine(build.call)).to include("sw-code-block__copy")
      expect(render_via_opal(build.call)).not_to include("sw-code-block__copy")
    end
  end
end
