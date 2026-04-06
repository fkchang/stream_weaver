# frozen_string_literal: true

module StreamWeaver
  module Components
    # Slide within a SlideContainer.
    # Contains child components rendered as slide content.
    #
    # sw- CSS classes:
    #   sw-slide                - individual slide wrapper
    #   sw-slide--active        - currently visible slide (swap mode)
    #   sw-slide--title         - title slide type
    #   sw-slide--content       - content slide type
    #
    # @example
    #   slide "intro", "Introduction" do
    #     text "Welcome to the presentation"
    #   end
    class Slide < Base
      attr_reader :id, :title, :type
      attr_accessor :children

      # @param id [String] Unique identifier for this slide
      # @param title [String, nil] Optional slide title
      # @param type [Symbol] Slide type (:content, :title)
      # @param options [Hash] Additional HTML options
      def initialize(id, title = nil, type: :content, **options)
        @id = id.to_s
        @title = title
        @type = type.to_sym
        @children = []
        super(**options)
      end

      def render(view, state)
        view.adapter.render_slide(view, self, state)
      end

      # CSS class list
      def css_classes
        classes = ["sw-slide"]
        classes << "sw-slide--#{@type}"
        classes.join(" ")
      end
    end

    # Container for navigable slides.
    # Supports two modes:
    #   :swap        -- one slide visible at a time, Back/Next buttons, fade transition (deck)
    #   :scroll_snap -- all slides rendered, CSS scroll-snap-type: y mandatory (explainer)
    #
    # Both modes share: keyboard navigation, progress tracking, Alpine.js x-data for current index.
    #
    # sw- CSS classes:
    #   sw-slide-container              - outer container
    #   sw-slide-container--swap        - swap mode
    #   sw-slide-container--scroll-snap - scroll-snap mode
    #   sw-slide-nav                    - navigation buttons wrapper
    #   sw-slide-nav__btn               - Back/Next buttons
    #   sw-slide-nav__btn--prev         - Back button modifier
    #   sw-slide-nav__btn--next         - Next button modifier
    #   sw-slide-progress               - progress bar
    #   sw-slide-progress--fixed        - fixed at top of viewport
    #   sw-slide-progress__bar          - progress bar fill
    #   sw-slide-dots                   - navigation dots container
    #   sw-slide-dots__dot              - individual dot
    #   sw-slide-dots__dot--active      - active dot
    #   sw-slide-counter                - slide counter text (e.g. "2 / 5")
    #
    # @example Swap mode (deck)
    #   slide_container mode: :swap, progress_bar: true do
    #     slide "intro", "Introduction" do
    #       text "Welcome"
    #     end
    #     slide "arch", "Architecture" do
    #       text "System design"
    #     end
    #   end
    #
    # @example Scroll-snap mode (explainer)
    #   slide_container mode: :scroll_snap, nav_dots: true, counter: true do
    #     slide "title", type: :title do
    #       header1 "Title"
    #     end
    #     slide "content1" do
    #       text "Content..."
    #     end
    #   end
    class SlideContainer < Base
      attr_reader :mode, :progress_bar, :nav_dots, :counter, :keyboard_nav
      attr_accessor :children

      # @param mode [Symbol] Display mode (:swap or :scroll_snap)
      # @param progress_bar [Boolean] Show progress bar (default: true)
      # @param keyboard_nav [Boolean] Enable arrow key navigation (default: true)
      # @param nav_dots [Boolean] Show navigation dots (default: false)
      # @param counter [Boolean] Show slide counter (default: false)
      # @param options [Hash] Additional options
      def initialize(mode: :swap, progress_bar: true, keyboard_nav: true,
                     nav_dots: false, counter: false, **options)
        @mode = mode.to_sym
        @progress_bar = progress_bar
        @keyboard_nav = keyboard_nav
        @nav_dots = nav_dots
        @counter = counter
        @children = []
        super(**options)
      end

      def render(view, state)
        view.adapter.render_slide_container(view, self, state)
      end

      # Number of slides
      def slide_count
        @children.length
      end

      # Whether swap mode
      def swap?
        @mode == :swap
      end

      # Whether scroll-snap mode
      def scroll_snap?
        @mode == :scroll_snap
      end

      # Generate a unique container ID
      def container_id
        @container_id ||= "sw-slides-#{object_id}"
      end

      # CSS class list
      def css_classes
        classes = ["sw-slide-container"]
        classes << "sw-slide-container--#{@mode.to_s.tr('_', '-')}"
        classes.join(" ")
      end
    end
  end
end
