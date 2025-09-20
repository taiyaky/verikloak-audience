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

    # Raised when audience is insufficient for the configured profile.
    class Forbidden < Error
      # @param msg [String]
      def initialize(msg = 'insufficient audience')
        super(msg, code: 'insufficient_audience', http_status: 403)
      end
    end
  end
end
