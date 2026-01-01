# frozen_string_literal: true

require 'rails/railtie'

module Verikloak
  module Audience
    # Warning messages for Railtie.
    module RailtieWarnings
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

      CORE_NOT_CONFIGURED_WARNING = <<~MSG
        [verikloak-audience] Skipping automatic middleware insertion because verikloak-rails
        is not fully configured (discovery_url is not set).

        The audience middleware requires the core Verikloak middleware to be present in the stack.
        Please configure verikloak-rails first by setting the discovery_url in your initializer.
      MSG

      UNCONFIGURED_WARNING = <<~MSG
        [verikloak-audience] Skipping configuration validation because required_aud is not configured.

        To use verikloak-audience, you must configure at least one required audience.
        Run `rails g verikloak:audience:install` to generate the initializer, or add:

          Verikloak::Audience.configure do |config|
            config.required_aud = ['your-audience']
          end

        WARNING: Without this configuration, ALL requests will be rejected with 403.
      MSG

      def log_warning(message)
        logger = (::Rails.logger if defined?(::Rails) && ::Rails.respond_to?(:logger))
        logger ? logger.warn(message) : Kernel.warn(message)
      end

      def warn_core_not_configured = log_warning(CORE_NOT_CONFIGURED_WARNING)
      def warn_missing_core_middleware = log_warning(WARNING_MESSAGE)
      def warn_unconfigured = log_warning(UNCONFIGURED_WARNING)
    end

    # Helper methods for Railtie configuration sync.
    module RailtieHelpers
      include RailtieWarnings

      def apply_verikloak_rails_configuration
        rails_config = verikloak_rails_config
        return unless rails_config

        Verikloak::Audience.configure do |cfg|
          sync_env_claims_key(cfg, rails_config)
          sync_required_aud(cfg, rails_config)
          sync_resource_client(cfg, rails_config)
          sync_skip_paths(cfg, rails_config)
        end
      end

      def discovery_url_configured?(value)
        return false unless value
        return !value.blank? if value.respond_to?(:blank?)
        return !value.empty? if value.respond_to?(:empty?)

        true
      end

      def middleware_not_found_error?(error)
        return true if error.class.name.to_s.include?('MiddlewareNotFound')

        message = error.message.to_s
        message.include?('No such middleware') ||
          message.include?('does not exist') ||
          message.match?(/middleware.*not found/i)
      end

      def verikloak_install_generator?(command)
        return false unless command.is_a?(String)

        command.start_with?('verikloak:') && command.end_with?(':install')
      end

      def first_cli_tokens
        tokens = []
        ARGV.each do |arg|
          next if arg.start_with?('-') || arg == 'rails'

          tokens << arg
          break if tokens.size >= 2
        end
        tokens
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
        unless blank?(current_client) || current_client == Verikloak::Audience::Configuration::DEFAULT_RESOURCE_CLIENT
          return
        end

        cfg.resource_client = audiences.first
      end

      def sync_skip_paths(cfg, rails_config)
        return unless rails_config.respond_to?(:skip_paths)

        paths = rails_config.skip_paths
        return if paths.nil?
        return unless cfg.skip_paths.nil? || cfg.skip_paths.empty?

        cfg.skip_paths = Array(paths).compact
      end

      def cfg_required_aud_blank?(cfg) = value_blank?(cfg.required_aud)

      def value_blank?(value)
        return true if value.nil?
        return true if value.respond_to?(:empty?) && value.empty?

        value.to_s.empty?
      end

      alias blank? value_blank?

      def normalized_audiences(source)
        Array(source).compact.map(&:to_s).reject(&:empty?)
      end
    end

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
      class << self
        attr_accessor :middleware_insertion_attempted, :unconfigured_warning_emitted

        include RailtieHelpers
      end

      @middleware_insertion_attempted = false
      @unconfigured_warning_emitted = false

      initializer 'verikloak_audience.middleware',
                  after: 'verikloak.configure',
                  before: :build_middleware_stack do |app|
        self.class.apply_verikloak_rails_configuration
        self.class.insert_middleware(app)
      end

      initializer 'verikloak_audience.configuration' do
        config.after_initialize do
          next if Verikloak::Audience::Railtie.skip_configuration_validation?
          next if Verikloak::Audience::Railtie.skip_unconfigured_validation?

          Verikloak::Audience.config.validate!
        end
      end

      COMMANDS_SKIPPING_VALIDATION = %w[generate g destroy d].freeze

      def self.insert_middleware(app)
        return unless defined?(::Verikloak::Middleware)

        if defined?(::Verikloak::Rails) && ::Verikloak::Rails.respond_to?(:config)
          discovery_url = ::Verikloak::Rails.config.discovery_url
          unless discovery_url_configured?(discovery_url)
            warn_core_not_configured
            return
          end
        end

        return if middleware_insertion_attempted

        middleware_stack = app.respond_to?(:config) ? app.config.middleware : app.middleware

        if middleware_stack.respond_to?(:include?) && middleware_stack.include?(::Verikloak::Audience::Middleware)
          return
        end

        self.middleware_insertion_attempted = true

        begin
          middleware_stack.insert_after ::Verikloak::Middleware, ::Verikloak::Audience::Middleware
        rescue StandardError => e
          raise unless middleware_not_found_error?(e)

          warn_missing_core_middleware
        end
      end

      def self.reset_middleware_insertion_flag!
        self.middleware_insertion_attempted = false
      end

      def self.skip_configuration_validation?
        tokens = first_cli_tokens
        return false if tokens.empty?

        return true if COMMANDS_SKIPPING_VALIDATION.include?(tokens.first)

        tokens.any? { |token| verikloak_install_generator?(token) }
      end

      def self.skip_unconfigured_validation?
        audiences_configured?
      end

      def self.audiences_configured?
        audiences = Verikloak::Audience.config.required_aud_list

        if audiences.empty?
          warn_unconfigured_once
          return true
        end

        false
      end

      def self.warn_unconfigured_once
        return if unconfigured_warning_emitted

        self.unconfigured_warning_emitted = true
        warn_unconfigured
      end
    end
  end
end
