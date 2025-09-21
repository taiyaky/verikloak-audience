# frozen_string_literal: true

require 'verikloak/audience/errors'

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
      DEFAULT_RESOURCE_CLIENT = 'rails-api'

      attr_accessor :profile, :required_aud, :resource_client,
                    :suggest_in_logs
      attr_reader :env_claims_key

      # Create a configuration with safe defaults.
      #
      # @return [void]
      def initialize
        @profile         = :strict_single
        @required_aud    = []
        @resource_client = DEFAULT_RESOURCE_CLIENT
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

      # Validate the configuration to ensure required values are present.
      #
      # @return [Configuration] the validated configuration
      def validate!
        audiences = required_aud_list
        if audiences.empty?
          raise Verikloak::Audience::ConfigurationError,
                'required_aud must include at least one audience'
        end

        profile_name = profile
        profile_name = profile_name.to_sym if profile_name.respond_to?(:to_sym)
        profile_name ||= :strict_single

        ensure_resource_client!(audiences) if profile_name == :resource_or_aud

        self
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

      # Build a deep-ish copy of `required_aud` so that mutations on copies
      # do not leak back into the original configuration instance.
      #
      # @param value [Array<String,Symbol>, String, Symbol, nil]
      # @return [Array<String,Symbol>, String, Symbol, nil]
      def duplicate_required_aud(value)
        return if value.nil?

        return value.map { |item| safe_dup(item) } if value.is_a?(Array)

        safe_dup(value)
      end

      # Ensure that the configured `resource_client` fits the `required_aud`
      # list when the :resource_or_aud profile is active. Attempts to infer
      # the client id from `required_aud` when possible and raises when
      # ambiguity remains.
      #
      # @param audiences [Array<String>] coerced required audiences
      # @return [void]
      def ensure_resource_client!(audiences)
        client = resource_client.to_s

        needs_inference = needs_resource_client_inference?(client, audiences)

        if needs_inference
          if audiences.one?
            self.resource_client = audiences.first
            client = resource_client.to_s
          else
            raise Verikloak::Audience::ConfigurationError,
                  'resource_client must match one of required_aud when using :resource_or_aud profile'
          end
        end

        return if audiences.include?(client)

        raise Verikloak::Audience::ConfigurationError,
              'resource_client must match one of required_aud when using :resource_or_aud profile'
      end

      # Decide whether the resource client should be inferred from the
      # required audiences based on the current client value.
      #
      # @param client [String]
      # @param audiences [Array<String>]
      # @return [Boolean]
      def needs_resource_client_inference?(client, audiences)
        client.empty? ||
          (client == DEFAULT_RESOURCE_CLIENT && !audiences.include?(client))
      end
    end
  end
end
