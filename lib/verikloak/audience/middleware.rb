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
      end

      # Evaluate the request against the audience profile.
      #
      # @param env [Hash] Rack environment
      # @return [Array(Integer, Hash, #each)] Rack response triple
      def call(env)
        claims = env[@config.env_claims_key] || {}
        return @app.call(env) if Checker.ok?(claims, @config)

        if @config.suggest_in_logs
          suggestion = Checker.suggest(claims, @config)
          aud_view = Array(claims['aud']).inspect
          warn("[verikloak-audience] insufficient_audience; suggestion profile=:#{suggestion} aud=#{aud_view}")
        end

        body = { error: 'insufficient_audience',
                 message: "Audience not acceptable for profile #{@config.profile}" }.to_json
        headers = { 'Content-Type' => 'application/json' }
        [403, headers, [body]]
      end

      private

      # Apply provided options to the configuration instance.
      #
      # @param opts [Hash]
      # @return [void]
      def apply_overrides!(opts)
        cfg = @config
        opts.each do |k, v|
          cfg.public_send("#{k}=", v) if cfg.respond_to?("#{k}=")
        end
      end
    end
  end
end
