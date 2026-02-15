# frozen_string_literal: true

require 'json'
require 'verikloak/audience'
require 'verikloak/audience/configuration'
require 'verikloak/audience/checker'
require 'verikloak/audience/errors'
require 'verikloak/error_response'
require 'verikloak/skip_path_matcher'

module Verikloak
  module Audience
    # Rack middleware that validates audience claims according to configured profile.
    #
    # Place this middleware after the core {::Verikloak::Middleware} so that
    # verified token claims are already available in the Rack env.
    class Middleware
      include Verikloak::SkipPathMatcher

      # @param app [#call] next Rack application
      # @param opts [Hash] configuration overrides (see {Configuration})
      # @option opts [Symbol] :profile (:strict_single, :allow_account, :any_match, :resource_or_aud)
      # @option opts [Array<String>,String,Symbol] :required_aud
      # @option opts [String] :resource_client
      # @option opts [String] :env_claims_key
      # @option opts [Boolean] :suggest_in_logs
      # @option opts [Array<String, Regexp>] :skip_paths
      def initialize(app, **opts)
        @app = app
        @config = Verikloak::Audience.config.dup
        apply_overrides!(opts)
        @config.validate! unless skip_validation?
        compile_skip_paths(@config.skip_paths || [])
      end

      # Evaluate the request against the audience profile.
      #
      # @param env [Hash] Rack environment
      # @return [Array(Integer, Hash, #each)] Rack response triple
      def call(env)
        # Skip audience validation for configured paths (e.g., health checks)
        path = env['PATH_INFO'] || env['REQUEST_PATH'] || ''
        return @app.call(env) if skip?(path)

        env_key = @config.env_claims_key
        claims = env[env_key] || env[env_key&.to_sym] || {}
        return @app.call(env) if Checker.ok?(claims, @config)

        if @config.suggest_in_logs
          suggestion = Checker.suggest(claims, @config)
          aud_view = Array(claims['aud']).inspect
          log_warning(env,
                      "[verikloak-audience] insufficient_audience; suggestion profile=:#{suggestion} aud=#{aud_view}")
        end

        Verikloak::ErrorResponse.build(
          code: 'insufficient_audience',
          message: "Audience not acceptable for profile #{@config.profile}",
          status: 403
        )
      end

      private

      # Apply provided options to the configuration instance.
      #
      # @param opts [Hash] raw overrides provided to the middleware
      # @return [void]
      def apply_overrides!(opts)
        cfg = @config
        opts.each do |key, value|
          writer = "#{key}="
          unless cfg.respond_to?(writer)
            raise Verikloak::Audience::ConfigurationError,
                  "unknown middleware option :#{key}"
          end

          cfg.public_send(writer, value)
        end
      end

      # Determine whether configuration validation should run. This allows
      # Rails generators to boot without a fully-populated configuration since
      # the install task is responsible for creating it. Also skips validation
      # when configuration is not explicitly set up.
      #
      # @return [Boolean]
      def skip_validation?
        # Skip if Railtie indicates generator mode
        if defined?(::Verikloak::Audience::Railtie)
          if ::Verikloak::Audience::Railtie.respond_to?(:skip_configuration_validation?) && ::Verikloak::Audience::Railtie.skip_configuration_validation?
            return true
          end

          # Skip if configuration is incomplete (no audiences configured)
          if ::Verikloak::Audience::Railtie.respond_to?(:skip_unconfigured_validation?) && ::Verikloak::Audience::Railtie.skip_unconfigured_validation?
            return true
          end
        end

        false
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
