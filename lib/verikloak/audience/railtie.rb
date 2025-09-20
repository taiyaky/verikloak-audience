# frozen_string_literal: true

require 'rails/railtie'

module Verikloak
  module Audience
    # Rails integration for verikloak-audience.
    #
    # This Railtie automatically inserts {Verikloak::Audience::Middleware}
    # into the Rails middleware stack directly after {::Verikloak::Middleware}
    # when it is present.
    #
    # If the core Verikloak middleware is not available, nothing is inserted.
    # You may still customize the placement in your application via
    # `config.middleware`.
    #
    # @example Configure placement and options
    #   # config/application.rb
    #   config.middleware.insert_after Verikloak::Middleware,
    #     Verikloak::Audience::Middleware,
    #     profile: :allow_account,
    #     required_aud: ['rails-api'],
    #     resource_client: 'rails-api',
    #     env_claims_key: 'verikloak.user',
    #     suggest_in_logs: true
    class Railtie < ::Rails::Railtie
      # Adds the audience middleware after the core Verikloak middleware
      # when available.
      #
      # @param app [Rails::Application] the Rails application instance
      initializer 'verikloak_audience.middleware' do |app|
        # Insert automatically after core verikloak if present
        self.class.insert_middleware(app)
      end

      # Performs the insertion into the middleware stack when the core
      # Verikloak middleware is available. Extracted for testability without
      # requiring a full Rails boot process.
      #
      # @param app [#middleware] An object exposing a Rack middleware stack via `#middleware`.
      # @return [void]
      def self.insert_middleware(app)
        return unless defined?(::Verikloak::Middleware)

        app.middleware.insert_after ::Verikloak::Middleware, ::Verikloak::Audience::Middleware
      end
    end
  end
end
