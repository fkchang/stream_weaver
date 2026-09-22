# frozen_string_literal: true

module StreamWeaver
  module Components
    # Presentation deck: a SlideContainer (swap mode) with 16:9 stage
    # chrome -- a recurring footer line and per-slide page numbers --
    # plus presentation slide layouts driven by Slide#type
    # (:title, :section, :cards, :milestones).
    #
    # Navigation, keyboard handling, and progress tracking are inherited
    # from SlideContainer unchanged; this class only adds the stage chrome
    # options. Rendering branches on #presentation? inside
    # render_slide_container.
    #
    # sw- CSS classes (see AlpineJS::PRESENTATION_CSS):
    #   sw-presentation          - deck wrapper modifier
    #   sw-pres-stage            - 16:9 slide stage
    #   sw-pres-footer           - recurring footer bar per slide
    #   sw-pres-footer__text     - footer text (left)
    #   sw-pres-footer__number   - slide number (right)
    #   sw-pres-kicker           - small uppercase accent label
    #   sw-pres-subtitle         - slide subtitle
    #   sw-pres-meta             - slide metadata line
    #   sw-pres-section-number   - big section number block
    #
    # @example
    #   presentation footer: "Acme – Confidential · Kickoff" do
    #     slide "title", "Acme Project", type: :title, kicker: "PROJECT KICKOFF" do
    #       phase "PHASE 1", "Discovery", "2 weeks"
    #     end
    #     slide "sec1", "Overview", type: :section, number: "01"
    #   end
    class Presentation < SlideContainer
      attr_reader :footer, :slide_numbers

      # @param footer [String, nil] Recurring footer text on every slide
      # @param slide_numbers [Boolean] Show per-slide page numbers (default: true)
      # @param options [Hash] SlideContainer options (mode is pinned to :swap)
      def initialize(footer: nil, slide_numbers: true, **options)
        options.delete(:mode) # presentations are always swap decks
        super(mode: :swap, **options)
        @footer = footer
        @slide_numbers = slide_numbers
      end

      def presentation?
        true
      end

      def css_classes
        "#{super} sw-presentation"
      end
    end

    # Phase entry on a presentation title slide
    # ("PHASE 1 / Discovery & Planning / 2.5 weeks · Sep 23 – Oct 9").
    # Rendered as an accent-left card inside a .sw-pres-phases strip.
    class Phase < Base
      attr_reader :label, :title, :meta

      def initialize(label, title, meta = nil, **options)
        @label = label
        @title = title
        @meta = meta
        super(**options)
      end

      def render(view, state)
        view.adapter.render_phase(view, self, state)
      end
    end

    # Dated milestone node on a presentation timeline slide.
    # Number defaults to the node's 1-based position within the slide's
    # track (assigned by the presentation renderer when unset).
    class Milestone < Base
      attr_reader :date, :label, :description
      attr_accessor :number

      def initialize(date, label, description = nil, number: nil, **options)
        @date = date
        @label = label
        @description = description
        @number = number
        super(**options)
      end

      def render(view, state)
        view.adapter.render_milestone(view, self, state)
      end
    end
  end
end
