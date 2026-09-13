#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/stream_weaver"
require_relative "shared"
require_relative "pages/overview"
require_relative "pages/agents"
require_relative "pages/visuals"
require_relative "pages/documents"
require_relative "pages/applications"
require_relative "pages/review"

LandingPagesDefinition = StreamWeaver::App.new(
  "StreamWeaver — Express More",
  layout: :fluid,
  chrome: false,
  components: [LandingPages::Helpers]
) do
  use_stylesheet File.read(File.join(LandingPages::ROOT, "landing_pages.css"))
  route_by :page, LandingPages::ROUTES
  state[:page] ||= :overview

  page = state[:page].to_sym
  renderer = {
    overview: LandingPages::Pages::Overview,
    agents: LandingPages::Pages::Agents,
    visuals: LandingPages::Pages::Visuals,
    documents: LandingPages::Pages::Documents,
    applications: LandingPages::Pages::Applications,
    review: LandingPages::Pages::Review
  }.fetch(page, LandingPages::Pages::Overview)

  renderer.render(self)
end

LandingPagesApp = LandingPagesDefinition.generate

LandingPagesApp.run! if __FILE__ == $PROGRAM_NAME
