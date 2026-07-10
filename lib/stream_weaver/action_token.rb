# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "securerandom"

module StreamWeaver
  module ActionToken
    class Invalid < StandardError; end

    module_function

    def encode(payload)
      body = Base64.urlsafe_encode64(JSON.generate(payload), padding: false)
      "#{body}.#{signature(body)}"
    end

    def decode(token)
      body, supplied = token.to_s.split(".", 2)
      raise Invalid unless body && supplied && secure_compare(signature(body), supplied)

      JSON.parse(Base64.urlsafe_decode64(body), symbolize_names: true)
    rescue JSON::ParserError, ArgumentError
      raise Invalid
    end

    def fingerprint(token)
      OpenSSL::Digest::SHA256.hexdigest(token.to_s)
    end

    def secret
      @secret ||= begin
        configured = ENV["SW_SECRET"]
        unless configured && !configured.empty?
          warn "StreamWeaver: SW_SECRET is not set; action tokens will not work across multiple workers."
          configured = SecureRandom.hex(32)
        end
        configured
      end
    end

    def reset_secret!
      @secret = nil
    end

    def signature(body)
      Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", secret, body), padding: false)
    end
    private_class_method :signature

    def secure_compare(left, right)
      return false unless left.bytesize == right.bytesize
      OpenSSL.fixed_length_secure_compare(left, right)
    end
    private_class_method :secure_compare
  end
end
