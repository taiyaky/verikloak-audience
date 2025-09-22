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

      initializer 'verikloak_audience.configuration' do
        config.after_initialize do
          next if Verikloak::Audience::Railtie.skip_configuration_validation?

          Verikloak::Audience.config.validate!
        end
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

      # Rails short commands (`g`, `d`) are stripped from ARGV fairly early in
      # the boot process. When that happens the first argument becomes the
      # generator namespace (e.g. `verikloak:install`). Include it here so the
      # install generator can run before `required_aud` is configured.
      COMMANDS_SKIPPING_VALIDATION = %w[generate g destroy d verikloak:install].freeze

      # Detect whether Rails is currently executing a generator-style command.
      # Generators boot the application before configuration exists, so we
      # temporarily skip validation to let the install task complete.
      #
      # @return [Boolean]
      def self.skip_configuration_validation?
        return false unless defined?(Rails::Generators)

        command = first_rails_command
        COMMANDS_SKIPPING_VALIDATION.include?(command)
      end

      # Capture the first non-option argument passed to the Rails CLI,
      # ignoring wrapper tokens such as "rails".
      #
      # @return [String, nil]
      def self.first_rails_command
        ARGV.each do |arg|
          next if arg.start_with?('-')
          next if arg == 'rails'

          return arg
        end

        nil
      end
    end
  end
end
