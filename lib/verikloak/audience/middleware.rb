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

        claims = read_claims(env)
        begin
          authorized = Checker.ok?(claims, @config)
        rescue Verikloak::Audience::ConfigurationError => e
          return configuration_error_response(env, e)
        end
        return @app.call(env) if authorized

        log_rejection(env, claims)

        Verikloak::ErrorResponse.build(
          code: 'insufficient_audience',
          message: "Audience not acceptable for profile #{@config.profile}",
          status: 403
        )
      end

      private

      # Read verified claims from the Rack env under the configured key.
      #
      # @param env [Hash] Rack environment
      # @return [Object] raw claims value (normalized later by {Checker})
      def read_claims(env)
        env_key = @config.env_claims_key
        env[env_key] || env[env_key.to_sym] || {}
      end

      # Log a configuration failure and render it as a generic JSON error
      # response instead of leaking a raw exception through the Rack stack.
      # The failure detail goes to the server log only, never to the client.
      # Boot-time validation normally prevents this path; it guards
      # deployments where validation was skipped (e.g. unconfigured Rails
      # boot).
      #
      # @param env [Hash] Rack environment
      # @param error [Verikloak::Audience::ConfigurationError]
      # @return [Array(Integer, Hash, #each)] Rack response triple
      def configuration_error_response(env, error)
        log_warning(env, "[verikloak-audience] configuration error: #{error.message}")

        Verikloak::ErrorResponse.build(
          code: error.code,
          message: 'audience configuration error',
          status: error.http_status
        )
      end

      # Emit the failure log (with a profile suggestion when one fits) if
      # `suggest_in_logs` is enabled.
      #
      # @param env [Hash] Rack environment
      # @param claims [Object] raw claims value read from the env
      # @return [void]
      def log_rejection(env, claims)
        return unless @config.suggest_in_logs

        suggestion = Checker.suggest(claims, @config, fallback: nil)
        detail = suggestion ? "suggestion profile=:#{suggestion}" : 'no profile matches the observed aud'
        aud_view = Checker.observed_audiences(claims).inspect
        log_warning(env, "[verikloak-audience] insufficient_audience; #{detail} aud=#{aud_view}")
      end

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
      # when configuration is not explicitly set up. The middleware's own
      # (post-override) configuration decides the unconfigured case, so
      # options passed to `use` are validated even when the global
      # configuration is untouched.
      #
      # @return [Boolean]
      def skip_validation?
        return false unless defined?(::Verikloak::Audience::Railtie)

        railtie = ::Verikloak::Audience::Railtie
        railtie.respond_to?(:skip_validation?) && railtie.skip_validation?(@config)
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
