# frozen_string_literal: true

module Verikloak
  module Audience
    # Configuration holder for verikloak-audience.
    #
    # @!attribute [rw] profile
    #   The enforcement profile to use.
    #   @return [:strict_single, :allow_account, :resource_or_aud]
    # @!attribute [rw] required_aud
    #   Required audience(s). Can be a String/Symbol or an Array of them.
    #   @return [Array<String,Symbol>, String, Symbol]
    # @!attribute [rw] resource_client
    #   Client id to use for `resource_access[client].roles` lookup.
    #   @return [String]
    # @!attribute [rw] env_claims_key
    #   Rack env key from which to read verified claims.
    #   @return [String]
    # @!attribute [rw] suggest_in_logs
    #   Whether to log a suggestion when audience validation fails.
    #   @return [Boolean]
    class Configuration
      attr_accessor :profile, :required_aud, :resource_client,
                    :env_claims_key, :suggest_in_logs

      # Create a configuration with safe defaults.
      #
      # @return [void]
      def initialize
        @profile         = :strict_single
        @required_aud    = []
        @resource_client = 'rails-api'
        @env_claims_key  = 'verikloak.user'
        @suggest_in_logs = true
      end

      # Coerce `required_aud` into an array of strings.
      #
      # @return [Array<String>]
      def required_aud_list
        Array(required_aud).map(&:to_s)
      end
    end
  end
end
