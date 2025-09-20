# frozen_string_literal: true

module Verikloak
  module Audience
    # Base error for audience failures.
    #
    # @!attribute [r] code
    #   Machine-friendly error code (e.g. "insufficient_audience").
    #   @return [String]
    # @!attribute [r] http_status
    #   HTTP status code associated with the error.
    #   @return [Integer]
    class Error < StandardError
      attr_reader :code, :http_status

      # @param msg [String] human-readable error message
      # @param code [String] machine-friendly error code
      # @param http_status [Integer] associated HTTP status
      def initialize(msg = 'audience error', code: 'audience_error', http_status: 403)
        super(msg)
        @code = code
        @http_status = http_status
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
