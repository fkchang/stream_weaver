# frozen_string_literal: true

# Opal compatibility stub for the `diffy` gem.
#
# diffy shells out to the system `diff(1)` binary, which does not exist in the
# browser. DiffBlock is a behavioral/server-side component and is not part of
# the document subset, but components.rb requires it unconditionally — without
# this stub the whole Opal bundle fails to boot with "cannot load such file --
# diffy", taking every document component down with it.
module Diffy
  class Diff
    def initialize(*, **) = nil
    def to_s(*) = ""
    def each(&) = nil
  end
end
