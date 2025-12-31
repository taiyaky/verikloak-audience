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
      initializer 'verikloak_audience.middleware',
                  after: 'verikloak.configure',
                  before: :build_middleware_stack do |app|
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

      # Tracks whether middleware insertion has been attempted to prevent
      # duplicate insertions when both railtie and generator initializer run.
      # In Rails 8.x+, middleware operations may be queued and `include?` may
      # not reflect pending insertions, so we use this flag as an additional
      # safeguard.
      @middleware_insertion_attempted = false

      class << self
        attr_accessor :middleware_insertion_attempted
      end

      # Performs the insertion into the middleware stack when the core
      # Verikloak middleware is available and already present. Extracted for
      # testability without requiring a full Rails boot process.
      #
      # Insert the audience middleware after the base Verikloak middleware when
      # both are available on the stack.
      #
      # In Rails 8.x+, middleware stack operations may be queued rather than
      # immediately applied, so `include?` checks may return false even when
      # the middleware will be inserted. We use `insert_after` with exception
      # handling to gracefully handle this case.
      #
      # @param app [#middleware] An object exposing a Rack middleware stack via `#middleware`.
      # @return [void]
      def self.insert_middleware(app)
        return unless defined?(::Verikloak::Middleware)

        # Skip if we have already attempted insertion (handles Rails 8+ queued operations)
        return if middleware_insertion_attempted

        # Use app.config.middleware for queued operations in Rails 8.x+
        # This ensures the insert_after operation is queued and applied during
        # build_middleware_stack, maintaining proper ordering with verikloak-rails
        middleware_stack = app.respond_to?(:config) ? app.config.middleware : app.middleware

        # Skip if already present (avoid duplicate insertion)
        if middleware_stack.respond_to?(:include?) &&
           middleware_stack.include?(::Verikloak::Audience::Middleware)
          return
        end

        # Mark as attempted before insertion to prevent concurrent/subsequent calls
        self.middleware_insertion_attempted = true

        # Attempt to insert after the core Verikloak middleware.
        # In Rails 8.x+, the middleware may be queued but not yet visible via include?,
        # so we try the insertion and handle any exceptions gracefully.
        begin
          middleware_stack.insert_after ::Verikloak::Middleware, ::Verikloak::Audience::Middleware
        rescue StandardError => e
          # Handle middleware not found errors (varies by Rails version):
          # - Rails 8+: RuntimeError with "No such middleware" message
          # - Earlier: ActionDispatch::MiddlewareStack::MiddlewareNotFound
          raise unless middleware_not_found_error?(e)

          warn_missing_core_middleware
        end
      end

      # Determines if the given exception indicates a middleware not found error.
      # This handles variations across Rails versions:
      # - Rails 8+: RuntimeError with "No such middleware" message
      # - Rails 7 and earlier: ActionDispatch::MiddlewareStack::MiddlewareNotFound
      #
      # @param error [StandardError] the exception to check
      # @return [Boolean] true if the error indicates missing middleware
      def self.middleware_not_found_error?(error)
        # Check exception class name (works for Rails 7's MiddlewareNotFound)
        return true if error.class.name.to_s.include?('MiddlewareNotFound')

        # Check message patterns for Rails 8+ RuntimeError
        message = error.message.to_s
        message.include?('No such middleware') ||
          message.include?('does not exist') ||
          message.match?(/middleware.*not found/i)
      end

      # Resets the insertion flag. Primarily used for testing to allow
      # multiple insertion attempts within the same process.
      #
      # @return [void]
      def self.reset_middleware_insertion_flag!
        self.middleware_insertion_attempted = false
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

        # Resolve the verikloak-rails configuration object if the gem is loaded.
        #
        # @return [Verikloak::Rails::Configuration, nil]
        def verikloak_rails_config
          return unless defined?(::Verikloak::Rails)
          return unless ::Verikloak::Rails.respond_to?(:config)

          ::Verikloak::Rails.config
        rescue StandardError
          nil
        end

        # Align the environment claims key with the one configured in verikloak-rails.
        #
        # @param cfg [Verikloak::Audience::Configuration]
        # @param rails_config [Verikloak::Rails::Configuration]
        # @return [void]
        def sync_env_claims_key(cfg, rails_config)
          return unless rails_config.respond_to?(:user_env_key)

          user_key = rails_config.user_env_key
          return if blank?(user_key)

          current = cfg.env_claims_key
          return unless current.nil? || current == Verikloak::Audience::Configuration::DEFAULT_ENV_CLAIMS_KEY

          cfg.env_claims_key = user_key
        end

        # Populate required audiences from the verikloak-rails configuration when absent.
        #
        # @param cfg [Verikloak::Audience::Configuration]
        # @param rails_config [Verikloak::Rails::Configuration]
        # @return [void]
        def sync_required_aud(cfg, rails_config)
          return unless cfg_required_aud_blank?(cfg)
          return unless rails_config.respond_to?(:audience)

          audiences = normalized_audiences(rails_config.audience)
          return if audiences.empty?

          cfg.required_aud = audiences.size == 1 ? audiences.first : audiences
        end

        # Infer the resource client based on the configured audience when possible.
        #
        # @param cfg [Verikloak::Audience::Configuration]
        # @param rails_config [Verikloak::Rails::Configuration]
        # @return [void]
        def sync_resource_client(cfg, rails_config)
          return unless rails_config.respond_to?(:audience)

          audiences = normalized_audiences(rails_config.audience)
          return unless audiences.size == 1

          current_client = cfg.resource_client
          unless blank?(current_client) || current_client == Verikloak::Audience::Configuration::DEFAULT_RESOURCE_CLIENT
            return
          end

          cfg.resource_client = audiences.first
        end

        # Determine whether the audience configuration is effectively empty.
        #
        # @param cfg [Verikloak::Audience::Configuration]
        # @return [Boolean]
        def cfg_required_aud_blank?(cfg)
          value_blank?(cfg.required_aud)
        end

        # Generic blank? helper that tolerates nil, empty, or blank-ish values.
        #
        # @param value [Object]
        # @return [Boolean]
        def value_blank?(value)
          return true if value.nil?
          return true if value.respond_to?(:empty?) && value.empty?

          value.to_s.empty?
        end

        alias blank? value_blank?

        # Coerce the given source into an array of non-empty string audiences.
        #
        # @param source [Object]
        # @return [Array<String>]
        def normalized_audiences(source)
          Array(source).compact.map(&:to_s).reject(&:empty?)
        end
      end
    end
  end
end
