# frozen_string_literal: true

# Verikloak::Audience provides Audience integration over Keycloak claims.
require 'verikloak/audience/version'
require 'verikloak/audience/configuration'
require 'verikloak/audience/errors'
require 'verikloak/audience/checker'
require 'verikloak/audience/railtie' if defined?(Rails::Railtie)

module Verikloak
  # Audience configuration entrypoint and helpers.
  # This file also requires the public components of the gem.
  module Audience
    autoload :Middleware, 'verikloak/audience/middleware'

    class << self
      # Configure verikloak-audience.
      #
      # When a block is given, the current configuration is yielded so callers
      # can mutate settings in one place.
      #
      # @yield [config] yields the current configuration for mutation
      # @yieldparam config [Verikloak::Audience::Configuration]
      # @return [Verikloak::Audience::Configuration] the resulting configuration
      def configure
        @config ||= Configuration.new
        yield @config if block_given?
        @config
      end

      # Access the current configuration without mutating it.
      #
      # @return [Verikloak::Audience::Configuration]
      def config
        @config ||= Configuration.new
      end

      # Reset configuration to defaults.
      # Intended for test teardown to prevent leakage between examples.
      #
      # @return [void]
      def reset!
        @config = nil
      end
    end
  end
end
