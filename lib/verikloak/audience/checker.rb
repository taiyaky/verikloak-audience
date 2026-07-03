# frozen_string_literal: true

require 'verikloak/audience/configuration'

module Verikloak
  module Audience
    # Audience profile checker functions.
    #
    # This module provides predicate helpers used by the middleware to decide
    # whether a given set of claims satisfies the configured profile.
    module Checker
      # Kept for backward compatibility; the canonical definition lives in
      # {Verikloak::Audience::Configuration::VALID_PROFILES}.
      VALID_PROFILES = Verikloak::Audience::Configuration::VALID_PROFILES

      module_function

      # Returns whether the given claims satisfy the configured profile.
      #
      # @param claims [Hash] OIDC claims (expects keys like "aud", "resource_access")
      # @param cfg [Verikloak::Audience::Configuration]
      # @raise [ConfigurationError] when the configured profile is unknown
      # @return [Boolean]
      def ok?(claims, cfg)
        claims = normalize_claims(claims)
        profile = cfg.validated_profile

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
      # @param required [Array<String,Symbol>, String, Symbol]
      # @return [Boolean]
      def strict_single?(claims, required)
        aud = normalized_audiences(claims)
        required = normalized_required(required)
        return false if required.empty?

        # Must contain all required and have no unexpected extra (order-insensitive)
        aud.sort == required.sort
      end

      # Validate aud allowing "account" as an extra value.
      #
      # @param claims [Hash]
      # @param required [Array<String,Symbol>, String, Symbol]
      # @return [Boolean]
      def allow_account?(claims, required)
        aud = normalized_audiences(claims)
        required = normalized_required(required)
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
      # @param required [Array<String,Symbol>, String, Symbol]
      # @return [Boolean]
      def any_match?(claims, required)
        aud = normalized_audiences(claims)
        required = normalized_required(required)
        return false if required.empty?

        # At least one of the required audiences must be present
        aud.intersect?(required)
      end

      # Permit when resource roles exist for the client; otherwise fallback to
      # {#allow_account?}.
      #
      # @param claims [Hash]
      # @param client [String]
      # @param required [Array<String,Symbol>, String, Symbol]
      # @return [Boolean]
      def resource_or_aud?(claims, client, required)
        roles = Array(claims.dig('resource_access', client, 'roles')).compact.reject { |r| r.to_s.empty? }
        return true unless roles.empty? # if meaningful roles for client exist, pass

        # otherwise enforce allow_account semantics by default
        allow_account?(claims, required)
      end

      # Suggest which profile might fit better, for migration aid.
      #
      # @param claims [Hash]
      # @param cfg [Verikloak::Audience::Configuration]
      # @param fallback [Symbol, nil] value returned when no profile accepts
      #   the claims (defaults to :strict_single, preserving the 1.0 contract)
      # @return [:strict_single, :allow_account, :any_match, :resource_or_aud, nil]
      #   the most fitting profile, or the fallback when none accepts
      def suggest(claims, cfg, fallback: :strict_single)
        claims = normalize_claims(claims)

        required = cfg.required_aud_list
        return :strict_single if strict_single?(claims, required)
        return :allow_account if allow_account?(claims, required)
        return :any_match if any_match?(claims, required)
        return :resource_or_aud if resource_or_aud?(claims, cfg.resource_client.to_s, required)

        fallback
      end

      # Audience values observed in the claims, normalized exactly like the
      # profile checks normalize them (useful for consistent logging).
      #
      # @param claims [Object] raw claims value (Hash or #to_hash)
      # @return [Array<String>]
      def observed_audiences(claims)
        normalized_audiences(normalize_claims(claims))
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
      rescue StandardError => e
        warn "[Verikloak::Audience] normalize_claims failed: #{e.class}: #{e.message}" if $DEBUG
        {}
      end
      private_class_method :normalize_claims

      # Normalize audience claims into a predictable array of strings.
      #
      # @param claims [Hash]
      # @return [Array<String>]
      def normalized_audiences(claims)
        Array(claims['aud']).map(&:to_s)
      end
      private_class_method :normalized_audiences

      # Coerce a required-audience input into an array of strings so that the
      # public predicates accept Symbols and single values consistently.
      #
      # @param required [Array<String,Symbol>, String, Symbol, nil]
      # @return [Array<String>]
      def normalized_required(required)
        Array(required).map(&:to_s)
      end
      private_class_method :normalized_required
    end
  end
end
