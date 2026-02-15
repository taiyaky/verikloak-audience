# frozen_string_literal: true

require 'verikloak/errors'

module Verikloak
  module Audience
    # Base error for audience failures.
    # Inherits from {Verikloak::Error} so that `rescue Verikloak::Error` catches all
    # Verikloak gem errors uniformly.
    #
    # Inherits `code` and `http_status` accessors from {Verikloak::Error}.
    # The parent class defines `attr_reader :code, :http_status` and accepts
    # `code:` / `http_status:` keyword arguments in its initializer.
    class Error < Verikloak::Error
      # @param msg [String] human-readable error message
      # @param code [String] machine-friendly error code
      # @param http_status [Integer] associated HTTP status
      def initialize(msg = 'audience error', code: 'audience_error', http_status: 403)
        super
      end
    end

    # Raised when verified claims do not satisfy the configured profile.
    # Typically emitted when the required audience list is empty or
    # mismatches the token audiences.
    class Forbidden < Error
      # Build a forbidden error with a customizable message while preserving
      # the standard machine-friendly code and HTTP status.
      #
      # @param msg [String] alternate human-readable explanation
      def initialize(msg = 'insufficient audience')
        super(msg, code: 'insufficient_audience', http_status: 403)
      end
    end

    # Raised when configuration is invalid.
    # Used when runtime configuration checks detect missing or incompatible
    # values before audience validation takes place.
    class ConfigurationError < Error
      # Build a configuration error while keeping a consistent error code
      # and a 500 HTTP status to signal an internal misconfiguration.
      #
      # @param msg [String] alternate human-readable explanation
      def initialize(msg = 'invalid audience configuration')
        super(msg, code: 'audience_configuration_error', http_status: 500)
      end
    end
  end
end
