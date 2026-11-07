# frozen_string_literal: true

require "rexml/document"

# Renders an ide_shell page and parses one region with REXML (Nokogiri is not
# in the lockfile). Alpine's @event shorthand is not a legal XML attribute
# name, so it is read back as on-event: @click="x" becomes on-click="x".
module IdeMarkup
  def render_ide_page(&block)
    app = StreamWeaver::App.new("IDE", chrome: false, theme: :ide) { ide_shell(&block) }
    app.rebuild_with_state({})
    StreamWeaver::Views::AppView.new(app, {}, StreamWeaver::Adapter::AlpineJS.new).call
  end

  # The first <tag class="block_class ..."> element of the page, parsed.
  def ide_region(html, tag, block_class)
    fragment = html[%r{<#{tag} class="#{block_class}[^"]*"[^>]*>.*?</#{tag}>}m]
    REXML::Document.new(fragment.gsub(/ @([\w.:-]+)=/, ' on-\1=')).root
  end

  def first(node, xpath) = REXML::XPath.first(node, xpath)
  def all(node, xpath) = REXML::XPath.match(node, xpath)
  def text_of(node) = REXML::XPath.match(node, ".//text()").join
  def classes(node) = node.attributes["class"].split
end
