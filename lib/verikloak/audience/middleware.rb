# frozen_string_literal: true

require 'json'
require 'verikloak/audience'
require 'verikloak/audience/configuration'
require 'verikloak/audience/checker'
require 'verikloak/audience/errors'

module Verikloak
  module Audience
    # Rack middleware that validates audience claims according to configured profile.
    #
    # Place this middleware after the core {::Verikloak::Middleware} so that
    # verified token claims are already available in the Rack env.
    class Middleware
      # @param app [#call] next Rack application
      # @param opts [Hash] configuration overrides (see {Configuration})
      # @option opts [Symbol] :profile
      # @option opts [Array<String>,String,Symbol] :required_aud
      # @option opts [String] :resource_client
      # @option opts [String] :env_claims_key
      # @option opts [Boolean] :suggest_in_logs
      def initialize(app, **opts)
        @app = app
        @config = Verikloak::Audience.config.dup
        apply_overrides!(opts)
        @config.validate! unless skip_validation?
      end

      # Evaluate the request against the audience profile.
      #
      # @param env [Hash] Rack environment
      # @return [Array(Integer, Hash, #each)] Rack response triple
      def call(env)
        env_key = @config.env_claims_key
        claims = env[env_key] || env[env_key&.to_sym] || {}
        return @app.call(env) if Checker.ok?(claims, @config)

        if @config.suggest_in_logs
          suggestion = Checker.suggest(claims, @config)
          aud_view = Array(claims['aud']).inspect
          log_warning(env,
                      "[verikloak-audience] insufficient_audience; suggestion profile=:#{suggestion} aud=#{aud_view}")
        end

        body = { error: 'insufficient_audience',
                 message: "Audience not acceptable for profile #{@config.profile}" }.to_json
        headers = { 'Content-Type' => 'application/json' }
        [403, headers, [body]]
      end

      private

      # Apply provided options to the configuration instance.
      #
      # @param opts [Hash] raw overrides provided to the middleware
      # @return [void]
      def apply_overrides!(opts)
        cfg = @config
        invalid_keys = opts.keys.reject { |key| cfg.respond_to?("#{key}=") }

        unless invalid_keys.empty?
          formatted = invalid_keys.map { |key| ":#{key}" }.join(', ')
          raise Verikloak::Audience::ConfigurationError,
                "unknown middleware option(s) #{formatted}"
        end

        opts.each do |key, value|
          cfg.public_send("#{key}=", value)
        end
      end

      # Determine whether configuration validation should run. This allows
      # Rails generators to boot without a fully-populated configuration since
      # the install task is responsible for creating it.
      #
      # @return [Boolean]
      def skip_validation?
        return false unless defined?(::Verikloak::Audience::Railtie)
        return false unless ::Verikloak::Audience::Railtie.respond_to?(:skip_configuration_validation?)

        ::Verikloak::Audience::Railtie.skip_configuration_validation?
      end

      # Emit a warning for failed audience checks using request-scoped loggers
      # when available.
      #
      # @param env [Hash] Rack environment
      # @param message [String] warning payload
      # @return [void]
      def log_warning(env, message)
        logger = env['verikloak.logger'] || env['rack.logger'] || env['action_dispatch.logger']
        return logger.warn(message) if logger.respond_to?(:warn)

        Kernel.warn(message)
      end
    end
  end
end
