# frozen_string_literal: true

module StreamWeaver
  module Components
    # Sticky sidebar table-of-contents with IntersectionObserver scroll spy.
    #
    # Desktop (>=1000px): sticky 170px sidebar with active-section highlighting.
    # Mobile (<1000px): horizontal scrollable sticky bar at the top.
    #
    # Sections are an array of hashes, each with :id and :label keys.
    # The :id corresponds to the DOM id of the target section element.
    #
    # @example
    #   sidebar_toc sections: [
    #     { id: "summary", label: "Executive Summary" },
    #     { id: "architecture", label: "Architecture" },
    #     { id: "risks", label: "Risks" }
    #   ]
    class SidebarToc < Base
      attr_reader :sections

      # @param sections [Array<Hash>] Array of { id:, label: } hashes
      # @param options [Hash] Additional options
      def initialize(sections:, **options)
        @sections = normalize_sections(sections)
        @options = options
      end

      def render(view, state)
        view.adapter.render_sidebar_toc(view, self, state)
      end

      private

      # Normalize sections to ensure string keys become symbols
      def normalize_sections(sections)
        sections.map do |s|
          {
            id: (s[:id] || s["id"]).to_s,
            label: (s[:label] || s["label"]).to_s
          }
        end
      end
    end
  end
end
