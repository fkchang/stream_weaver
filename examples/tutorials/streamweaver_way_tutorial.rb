#!/usr/bin/env ruby
# frozen_string_literal: true

# "Build My Todos: the StreamWeaver Way" -- the :doc-theme rendering.
#
# TWIN NOTICE: this file renders content it does not own. The words live in
# examples/tutorials/tutorial_content.rb and are rendered twice -- here as a
# StreamWeaver doc-app, and by examples/tutorials/render_markdown.rb into
# docs/tutorials/the-streamweaver-way.md. Edit the outline, never a twin.
#
#   SW_NO_OPEN=1 ruby examples/tutorials/streamweaver_way_tutorial.rb

require_relative '../../lib/stream_weaver'
require_relative 'tutorial_content'

TutorialApp = app TutorialContent::TITLE, theme: :doc do
  sidebar_toc sections: TutorialContent.toc

  doc_header(
    eyebrow: TutorialContent::EYEBROW,
    title: TutorialContent::TITLE,
    pills: TutorialContent::PILLS
  )

  md TutorialContent::LEAD

  TutorialContent::SECTIONS.each do |section|
    doc_section_header section[:number], section[:title], id: section[:id]

    section[:blocks].each do |kind, *rest|
      case kind
      when :md      then md rest[0]
      when :code    then code_block(rest[1], lang: rest[0])
      when :table   then table(headers: rest[0], rows: rest[1])
      when :callout
        variant, title, body = rest
        callout(variant: variant, title: title) { md body }
      else raise ArgumentError, "unknown tutorial block: #{kind.inspect}"
      end
    end
  end
end

TutorialApp.run! if __FILE__ == $PROGRAM_NAME
