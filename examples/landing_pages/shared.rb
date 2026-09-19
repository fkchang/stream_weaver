# frozen_string_literal: true

module LandingPages
  ROOT = File.expand_path(__dir__)

  ROUTES = {
    overview: "/",
    agents: "/agents",
    visuals: "/visuals",
    documents: "/documents",
    applications: "/applications",
    review: "/review"
  }.freeze

  LABELS = {
    overview: "Overview",
    agents: "Agents",
    visuals: "Visuals",
    documents: "Docs",
    applications: "Apps",
    review: "Review"
  }.freeze

  module Helpers
    def lp_page(page:, source:, &block)
      div class: "lp-page" do
        lp_navigation(page)
        div(class: "lp-main", &block)
        lp_source(source)
        lp_footer
      end
    end

    def lp_navigation(active_page)
      div class: "lp-nav" do
        link_to "STREAMWEAVER", href: "/", class: "lp-wordmark"
        div class: "lp-nav-links" do
          LandingPages::ROUTES.each do |page, path|
            link_to LandingPages::LABELS.fetch(page), href: path,
              class: "lp-nav-link#{' is-active' if page == active_page}"
          end
        end
      end
    end

    def lp_hero(eyebrow:, title:, summary:)
      div class: "lp-hero" do
        text eyebrow, class: "lp-eyebrow"
        header1 title, class: "lp-display"
        text summary, class: "lp-dek"
        div class: "lp-hero-actions" do
          link_to "Explore the example", href: "#example", class: "lp-pill lp-pill-primary"
          link_to "Inspect source", href: "#source", class: "lp-pill"
        end
      end
    end

    def lp_section_label(label, title, anchor: nil)
      options = { class: "lp-section-heading" }
      options[:id] = anchor if anchor
      div **options do
        text label, class: "lp-eyebrow"
        header2 title, class: "lp-heading"
      end
    end

    def lp_benefits(items)
      div class: "lp-benefits" do
        items.each_with_index do |(title, body), index|
          div class: "lp-benefit" do
            text format("%02d", index + 1), class: "lp-benefit-index"
            header3 title, class: "lp-benefit-title"
            text body, class: "lp-benefit-copy"
          end
        end
      end
    end

    def lp_audiences(ruby_author:, agent_author:, reader:)
      div class: "lp-audiences" do
        [
          ["IF YOU WRITE RUBY", ruby_author],
          ["IF YOUR AGENT WRITES IT", agent_author],
          ["IF YOU READ IT", reader]
        ].each do |label, body|
          div class: "lp-audience" do
            text label, class: "lp-eyebrow"
            text body, class: "lp-audience-copy"
          end
        end
      end
    end

    def lp_source(source)
      div id: "source", class: "lp-source" do
        collapsible "INSPECT THE DSL — #{File.basename(source)}" do
          code_block File.read(source, encoding: "UTF-8"), lang: "ruby", file: source.delete_prefix("#{LandingPages::ROOT}/")
        end
      end
    end

    def lp_footer
      div class: "lp-footer" do
        text "STREAMWEAVER / RUBY DSL FOR WORK YOU CAN SEE", class: "lp-eyebrow"
        link_to "Back to overview →", href: "/", class: "lp-footer-link"
      end
    end
  end
end
