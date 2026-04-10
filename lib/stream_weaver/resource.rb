# frozen_string_literal: true

module StreamWeaver
  RouteRule = Struct.new(:parser, :builder, :source, keyword_init: true)
  Field     = Struct.new(:name, :type, :opts)
end
