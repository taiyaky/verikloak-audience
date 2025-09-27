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
          self.class.apply_verikloak_rails_configuration
          next if Verikloak::Audience::Railtie.skip_configuration_validation?

          Verikloak::Audience.config.validate!
        end
      end

      # Performs the insertion into the middleware stack when the core
      # Verikloak middleware is available and already present. Extracted for
      # testability without requiring a full Rails boot process.
      #
      # @param app [#middleware] An object exposing a Rack middleware stack via `#middleware`.
      # @return [void]
      def self.insert_middleware(app)
        return unless defined?(::Verikloak::Middleware)

        middleware_stack = app.middleware
        return unless middleware_stack.respond_to?(:include?)

        return if middleware_stack.include?(::Verikloak::Audience::Middleware)

        unless middleware_stack.include?(::Verikloak::Middleware)
          warn_missing_core_middleware
          return
        end

        middleware_stack.insert_after ::Verikloak::Middleware, ::Verikloak::Audience::Middleware
      end

      WARNING_MESSAGE = <<~MSG
        [verikloak-audience] Skipping automatic middleware insertion because ::Verikloak::Middleware
        is not present in the Rails middleware stack.

        To enable verikloak-audience, first ensure that the core Verikloak middleware (`Verikloak::Middleware`)
        is added to your Rails middleware stack. Once the core middleware is present, you can run
        `rails g verikloak:audience:install` to generate the initializer for the audience middleware,
        or manually add:

          config.middleware.insert_after Verikloak::Middleware, Verikloak::Audience::Middleware

        This warning will disappear once the core middleware is properly configured and the audience
        middleware is inserted.
      MSG

      # Logs a warning message when the core Verikloak middleware is missing
      # from the Rails middleware stack. Uses the Rails logger if available,
      # otherwise falls back to Kernel.warn for output.
      #
      # This method is called when automatic middleware insertion is skipped
      # due to the absence of the required core middleware.
      #
      # @return [void]
      def self.warn_missing_core_middleware
        logger = (::Rails.logger if defined?(::Rails) && ::Rails.respond_to?(:logger))

        if logger
          logger.warn(WARNING_MESSAGE)
        else
          Kernel.warn(WARNING_MESSAGE)
        end
      end

      # Rails short commands (`g`, `d`) are stripped from ARGV fairly early in
      # the boot process. Treat `verikloak:*:install` generators as safe so they
      # can run before configuration files exist.
      COMMANDS_SKIPPING_VALIDATION = %w[generate g destroy d].freeze

      # Detect whether Rails is currently executing a generator-style command.
      # Generators boot the application before configuration exists, so we
      # temporarily skip validation to let the install task complete.
      #
      # @return [Boolean]
      def self.skip_configuration_validation?
        tokens = first_cli_tokens
        return false if tokens.empty?

        command = tokens.first
        return true if COMMANDS_SKIPPING_VALIDATION.include?(command)

        tokens.any? { |token| verikloak_install_generator?(token) }
      end

      # Capture the first non-option arguments passed to the Rails CLI,
      # ignoring wrapper tokens such as "rails". Only the first two tokens are
      # relevant for generator detection, so we keep the return list short.
      #
      # @return [Array<String>] ordered CLI tokens that may signal a generator
      def self.first_cli_tokens
        tokens = []

        ARGV.each do |arg|
          next if arg.start_with?('-')
          next if arg == 'rails'

          tokens << arg
          break if tokens.size >= 2
        end

        tokens
      end

      # Detect whether the provided CLI token refers to a Verikloak install
      # generator (e.g. `verikloak:install`, `verikloak:pundit:install`).
      #
      # @param command [String, nil] first non-option argument from ARGV
      # @return [Boolean]
      def self.verikloak_install_generator?(command)
        return false unless command.is_a?(String)

        command.start_with?('verikloak:') && command.end_with?(':install')
      end

      class << self
        # Synchronize configuration with verikloak-rails when it is present.
        # Aligns env_claims_key, required_aud, and resource_client defaults so
        # that both gems operate on the same Rack env payload and audience list.
        #
        # @return [void]
        def apply_verikloak_rails_configuration
          rails_config = verikloak_rails_config
          return unless rails_config

          Verikloak::Audience.configure do |cfg|
            sync_env_claims_key(cfg, rails_config)
            sync_required_aud(cfg, rails_config)
            sync_resource_client(cfg, rails_config)
          end
        end

        private

        def verikloak_rails_config
          return unless defined?(::Verikloak::Rails)
          return unless ::Verikloak::Rails.respond_to?(:config)

          ::Verikloak::Rails.config
        rescue StandardError
          nil
        end

        def sync_env_claims_key(cfg, rails_config)
          return unless rails_config.respond_to?(:user_env_key)

          user_key = rails_config.user_env_key
          return if blank?(user_key)

          current = cfg.env_claims_key
          return unless current.nil? || current == Verikloak::Audience::Configuration::DEFAULT_ENV_CLAIMS_KEY

          cfg.env_claims_key = user_key
        end

        def sync_required_aud(cfg, rails_config)
          return unless cfg_required_aud_blank?(cfg)
          return unless rails_config.respond_to?(:audience)

          audiences = normalized_audiences(rails_config.audience)
          return if audiences.empty?

          cfg.required_aud = audiences.size == 1 ? audiences.first : audiences
        end

        def sync_resource_client(cfg, rails_config)
          return unless rails_config.respond_to?(:audience)

          audiences = normalized_audiences(rails_config.audience)
          return unless audiences.size == 1

          current_client = cfg.resource_client
          unless current_client.nil? || current_client.empty? || current_client == Verikloak::Audience::Configuration::DEFAULT_RESOURCE_CLIENT
            return
          end

          cfg.resource_client = audiences.first
        end

        def cfg_required_aud_blank?(cfg)
          blank?(cfg.required_aud)
        end

        def blank?(value)
          return true if value.nil?
          return true if value.respond_to?(:empty?) && value.empty?

          value.to_s.empty?
        end

        def normalized_audiences(source)
          return [] if blank?(source)

          Array(source).map(&:to_s).reject(&:empty?)
        end
      end
    end
  end
end
