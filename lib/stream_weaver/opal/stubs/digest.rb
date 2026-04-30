# frozen_string_literal: true

module Digest
  # Opal compatibility stub. NOT MD5. NOT cryptographically secure.
  # Returns a 16-char hex string via djb2 for use as a stable ID only.
  # At runtime, App#button is patched in opal_entry.rb to use counter-based IDs,
  # so this is only called if unpatched code paths run during compilation.
  module MD5
    def self.hexdigest(str)
      hash = 5381
      str.each_char { |c| hash = ((hash << 5) + hash) + c.ord }
      format("%016x", hash & 0xFFFFFFFFFFFFFFFF)
    end
  end
end
