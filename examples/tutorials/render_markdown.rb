#!/usr/bin/env ruby
# frozen_string_literal: true

# "Build My Todos: the StreamWeaver Way" -- the markdown rendering.
#
# TWIN NOTICE: this file renders content it does not own. The words live in
# examples/tutorials/tutorial_content.rb and are rendered twice -- here into
# docs/tutorials/the-streamweaver-way.md, and by
# examples/tutorials/streamweaver_way_tutorial.rb as a :doc-theme StreamWeaver
# app. Edit the outline, never a twin.
#
# Regenerate the checked-in markdown:
#
#   ruby examples/tutorials/render_markdown.rb
#
# spec/tutorial_twins_spec.rb fails if the checked-in file differs from a fresh
# render, so the twins cannot drift apart silently.

require_relative 'tutorial_content'

module TutorialMarkdown
  OUTPUT_PATH = File.expand_path('../../docs/tutorials/the-streamweaver-way.md', __dir__)

  # The doc-app's callout variants map onto GitHub's alert syntax, which renders
  # as a coloured admonition there and degrades to a plain blockquote anywhere
  # else -- so the teaching weight of a `:error` gotcha survives both.
  VARIANT_ALERTS = {
    info: 'NOTE',
    tip: 'TIP',
    warning: 'WARNING',
    error: 'CAUTION',
    decision: 'IMPORTANT',
    success: 'NOTE',
    risk: 'CAUTION'
  }.freeze

  BANNER = <<~MD
    <!-- GENERATED FILE -- do not edit directly. -->
    <!-- Source outline: examples/tutorials/tutorial_content.rb -->
    <!-- Regenerate:     ruby examples/tutorials/render_markdown.rb -->
  MD

  class << self
    def render
      parts = [BANNER.strip, "# #{TutorialContent::TITLE}", pill_line,
               TutorialContent::LEAD.strip, contents]
      TutorialContent::SECTIONS.each { |section| parts << section(section) }
      "#{parts.join("\n\n")}\n"
    end

    def write!(path = OUTPUT_PATH)
      require 'fileutils'
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, render)
      path
    end

    private

    def pill_line
      pills = TutorialContent::PILLS.map { |p| p.is_a?(Hash) ? p[:text] : p }
      "*#{TutorialContent::EYEBROW}* · #{pills.join(' · ')}"
    end

    def contents
      lines = TutorialContent::SECTIONS.map do |s|
        "- [#{s[:number]}. #{s[:title]}](##{s[:id]})"
      end
      ['## Contents', '', *lines].join("\n")
    end

    def section(section)
      # An explicit anchor keeps the markdown's section ids identical to the
      # doc-app's `doc_section_header id:` values, rather than depending on how
      # a given renderer slugifies heading text.
      head = %(<a id="#{section[:id]}"></a>\n\n## #{section[:number]}. #{section[:title]})
      [head, *section[:blocks].map { |block| self.block(*block) }].join("\n\n")
    end

    def block(kind, *rest)
      case kind
      when :md      then rest[0].strip
      when :code    then "```#{rest[0]}\n#{rest[1].strip}\n```"
      when :table   then table(rest[0], rest[1])
      when :callout then callout(*rest)
      else raise ArgumentError, "unknown tutorial block: #{kind.inspect}"
      end
    end

    def callout(variant, title, body)
      quoted = body.strip.split("\n").map { |line| line.empty? ? '>' : "> #{line}" }
      ["> [!#{VARIANT_ALERTS.fetch(variant)}]", "> **#{title}**", '>', *quoted].join("\n")
    end

    # Separator cells are exactly three ASCII hyphens: some renderers turn
    # longer runs into em-dashes.
    def table(headers, rows)
      lines = [row(headers), "|#{(['---'] * headers.length).join('|')}|"]
      rows.each { |r| lines << row(r) }
      lines.join("\n")
    end

    def row(cells)
      "| #{cells.map { |c| c.to_s.gsub('|', '\\|') }.join(' | ')} |"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  path = TutorialMarkdown.write!
  puts "wrote #{path} (#{File.size(path)} bytes, #{File.readlines(path).length} lines)"
end
