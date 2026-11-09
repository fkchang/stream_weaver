# frozen_string_literal: true

# The classes on a page's <body> (or on its data-sw-body-class), as a list,
# so a spec asserts the set of classes rather than one ordering of them.
module BodyClassHelper
  def body_classes(html)
    html[/<body class="([^"]*)"/, 1].to_s.split
  end

  def data_body_classes(html)
    html[/data-sw-body-class="([^"]*)"/, 1].to_s.split
  end
end

RSpec.configure { |config| config.include BodyClassHelper }
