# frozen_string_literal: true

module Verikloak
  module Audience
    # Audience profile checker functions.
    #
    # This module provides predicate helpers used by the middleware to decide
    # whether a given set of claims satisfies the configured profile.
    module Checker
      VALID_PROFILES = %i[strict_single allow_account any_match resource_or_aud].freeze

      module_function

      # Returns whether the given claims satisfy the configured profile.
      #
      # @param claims [Hash] OIDC claims (expects keys like "aud", "resource_access")
      # @param cfg [Verikloak::Audience::Configuration]
      # @return [Boolean]
      def ok?(claims, cfg)
        claims = normalize_claims(claims)

        profile = cfg.profile
        profile = profile.to_sym if profile.respond_to?(:to_sym)
        profile = :strict_single if profile.nil?

        unless VALID_PROFILES.include?(profile)
          raise Verikloak::Audience::ConfigurationError,
                "unknown audience profile #{cfg.profile.inspect}"
        end

        case profile
        when :strict_single
          strict_single?(claims, cfg.required_aud_list)
        when :allow_account
          allow_account?(claims, cfg.required_aud_list)
        when :any_match
          any_match?(claims, cfg.required_aud_list)
        when :resource_or_aud
          resource_or_aud?(claims, cfg.resource_client.to_s, cfg.required_aud_list)
        end
      end

      # Validate that aud matches required exactly (order-insensitive).
      #
      # @param claims [Hash]
      # @param required [Array<String>]
      # @return [Boolean]
      def strict_single?(claims, required)
        aud = normalized_audiences(claims)
        return false if required.empty?

        # Must contain all required and have no unexpected extra (order-insensitive)
        (aud.sort == required.map(&:to_s).sort)
      end

      # Validate aud allowing "account" as an extra value.
      #
      # @param claims [Hash]
      # @param required [Array<String>]
      # @return [Boolean]
      def allow_account?(claims, required)
        aud = normalized_audiences(claims)
        return false if required.empty?

        # Permit 'account' extra
        extras = aud - required
        extras.delete('account')
        extras.empty? && (required - aud).empty?
      end

      # Validate that at least one required audience is present in the token.
      # More permissive than :strict_single; useful when multiple clients share audiences.
      #
      # @param claims [Hash]
      # @param required [Array<String>]
      # @return [Boolean]
      def any_match?(claims, required)
        aud = normalized_audiences(claims)
        return false if required.empty?

        # At least one of the required audiences must be present
        aud.intersect?(required.map(&:to_s))
      end

      # Permit when resource roles exist for the client; otherwise fallback to
      # {#allow_account?}.
      #
      # @param claims [Hash]
      # @param client [String]
      # @param required [Array<String>]
      # @return [Boolean]
      def resource_or_aud?(claims, client, required)
        roles = Array(claims.dig('resource_access', client, 'roles'))
        return true unless roles.empty? # if roles for client exist, pass

        # otherwise enforce allow_account semantics by default
        allow_account?(claims, required)
      end

      # Suggest which profile might fit better, for migration aid.
      #
      # @param claims [Hash]
      # @param cfg [Verikloak::Audience::Configuration]
      # @return [:strict_single, :allow_account, :resource_or_aud]
      def suggest(claims, cfg)
        claims = normalize_claims(claims)

        required = cfg.required_aud_list
        return :strict_single if strict_single?(claims, required)
        return :allow_account if allow_account?(claims, required)
        return :any_match if any_match?(claims, required)
        return :resource_or_aud if resource_or_aud?(claims, cfg.resource_client.to_s, required)

        :strict_single
      end

      # Normalize incoming claims to a Hash to guard against unexpected
      # env payloads or middleware ordering issues.
      #
      # @param claims [Object]
      # @return [Hash]
      def normalize_claims(claims)
        return {} if claims.nil?
        return claims if claims.is_a?(Hash)

        if claims.respond_to?(:to_hash)
          coerced = claims.to_hash
          return coerced if coerced.is_a?(Hash)
        end

        {}
      rescue StandardError
        {}
      end
      module_function :normalize_claims
      private_class_method :normalize_claims

      # Normalize audience claims into a predictable array of strings.
      #
      # @param claims [Hash]
      # @return [Array<String>]
      def normalized_audiences(claims)
        Array(claims['aud']).map(&:to_s)
      end
      module_function :normalized_audiences
      private_class_method :normalized_audiences
    end
  end
end
