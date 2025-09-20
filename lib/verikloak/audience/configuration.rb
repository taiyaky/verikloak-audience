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
                    :suggest_in_logs
      attr_reader :env_claims_key

      # Create a configuration with safe defaults.
      #
      # @return [void]
      def initialize
        @profile         = :strict_single
        @required_aud    = []
        @resource_client = 'rails-api'
        self.env_claims_key = 'verikloak.user'
        @suggest_in_logs = true
      end

      # Ensure `dup` produces an independent copy.
      #
      # @param source [Configuration]
      # @return [void]
      def initialize_copy(source)
        super
        @profile         = safe_dup(source.profile)
        @required_aud    = duplicate_required_aud(source.required_aud)
        @resource_client = safe_dup(source.resource_client)
        self.env_claims_key = safe_dup(source.env_claims_key)
        @suggest_in_logs = source.suggest_in_logs
      end

      # Coerce `required_aud` into an array of strings.
      #
      # @return [Array<String>]
      def required_aud_list
        Array(required_aud).map(&:to_s)
      end

      # @param value [#to_s, nil]
      # @return [void]
      def env_claims_key=(value)
        @env_claims_key = value&.to_s
      end

      private

      # Attempt to duplicate a value while tolerating non-duplicable inputs.
      # Returns `nil` when given nil and falls back to the original on duplication errors.
      #
      # @param value [Object, nil]
      # @return [Object, nil]
      def safe_dup(value)
        return if value.nil?

        value.dup
      rescue TypeError
        value
      end

      def duplicate_required_aud(value)
        return if value.nil?

        return value.map { |item| safe_dup(item) } if value.is_a?(Array)

        safe_dup(value)
      end
    end
  end
end
