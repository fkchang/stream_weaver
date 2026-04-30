# frozen_string_literal: true
# Minimal Digest stub for Opal browser compilation.
# Provides Digest::MD5.hexdigest using a pure-Ruby djb2 hash (no stdlib needed).
# This file exists so `require 'digest'` doesn't raise in the browser.

module Digest
  module MD5
    def self.hexdigest(str)
      # djb2 hash: fast pure-Ruby, no stdlib — good enough for stable button IDs
      hash = 5381
      str.each_byte { |b| hash = ((hash << 5) + hash) + b }
      # Produce 16 hex characters, take first 8 (matches original [0..7])
      format("%016x", hash & 0xFFFFFFFFFFFFFFFF)
    end
  end

  module SHA256
    def self.hexdigest(str)
      # Minimal stub — not cryptographically secure, only for non-security browser use
      Digest::MD5.hexdigest(str)
    end
  end
end
