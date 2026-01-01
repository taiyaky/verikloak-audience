# frozen_string_literal: true

require 'spec_helper'

# Provide a minimal Rails::Railtie stub and mark it as loaded so that
# requiring the gem's railtie file does not attempt to load the real Rails.
unless defined?(Rails::Railtie)
  module Rails
    class Railtie
      class Config
        attr_reader :after_initialize_callbacks

        def initialize
          @after_initialize_callbacks = []
        end

        def after_initialize(&block)
          @after_initialize_callbacks << block if block
        end
      end

      def self.initializers
        @initializers ||= []
      end

      # Support both `initializer 'name' do ... end` and
      # `initializer 'name', after: 'other' do ... end`
      def self.initializer(name, options = {}, &block)
        entry = [name, options, block]
        initializers << entry
        Rails::Railtie.initializers << entry unless equal?(Rails::Railtie)
      end

      def self.config
        @config ||= Config.new
      end

      def config
        self.class.config
      end
    end
  end
  $LOADED_FEATURES << 'rails/railtie'
end

require 'verikloak/audience/railtie'

RSpec.describe Verikloak::Audience::Railtie do
  let(:middleware_stack) { instance_double('MiddlewareStack') }
  let(:config) { instance_double('Config', middleware: middleware_stack) }
  let(:app) { instance_double('RailsApp', config: config, middleware: middleware_stack) }
  let(:configuration_initializer) do
    Rails::Railtie.initializers.find { |name, _| name == 'verikloak_audience.configuration' }
  end

  # Reset the insertion flag before each test to ensure clean state
  before do
    described_class.reset_middleware_insertion_flag!
  end

  it 'inserts after Verikloak::Middleware when defined' do
    begin
      # Define a dummy core middleware constant for the scope of the example
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      allow(middleware_stack).to receive(:include?).with(::Verikloak::Middleware).and_return(true)
      expect(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)

      described_class.insert_middleware(app)
    ensure
      # Clean up the dummy constant to avoid leakage
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'does nothing when Verikloak::Middleware is not defined' do
    if defined?(::Verikloak::Middleware)
      ::Verikloak.send(:remove_const, :Middleware)
    end
    allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
    allow(middleware_stack).to receive(:include?).with(anything).and_return(false)
    expect(described_class).not_to receive(:warn_missing_core_middleware)
    expect(middleware_stack).not_to receive(:insert_after)
    described_class.insert_middleware(app)
  end

  it 'skips insertion when Audience middleware is already present (include? early return)' do
    begin
      module ::Verikloak; class Middleware; end; end

      # Simulate middleware already present in stack
      allow(middleware_stack).to receive(:respond_to?).with(:include?).and_return(true)
      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(true)
      expect(middleware_stack).not_to receive(:insert_after)

      described_class.insert_middleware(app)
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'skips insertion when insertion has already been attempted (duplicate prevention flag)' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      allow(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)

      # First call should succeed
      described_class.insert_middleware(app)
      expect(middleware_stack).to have_received(:insert_after).once

      # Second call should be skipped due to flag
      described_class.insert_middleware(app)
      expect(middleware_stack).to have_received(:insert_after).once
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'does nothing when Verikloak::Middleware is not in the stack' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      # Simulate middleware not found by raising an error on insert_after
      allow(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)
        .and_raise(RuntimeError.new('No such middleware'))
      expect(described_class).to receive(:warn_missing_core_middleware)

      described_class.insert_middleware(app)
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'handles Rails 7 MiddlewareNotFound exception gracefully' do
    begin
      module ::Verikloak; class Middleware; end; end

      # Create a custom exception class to simulate Rails 7's MiddlewareNotFound
      middleware_not_found = Class.new(StandardError)
      stub_const('ActionDispatch::MiddlewareStack::MiddlewareNotFound', middleware_not_found)

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      allow(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)
        .and_raise(ActionDispatch::MiddlewareStack::MiddlewareNotFound.new('Verikloak::Middleware'))
      expect(described_class).to receive(:warn_missing_core_middleware)

      described_class.insert_middleware(app)
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'handles alternative error messages for middleware not found' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      # Test alternative error message pattern
      allow(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)
        .and_raise(RuntimeError.new('middleware does not exist in the stack'))
      expect(described_class).to receive(:warn_missing_core_middleware)

      described_class.insert_middleware(app)
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 're-raises unexpected exceptions' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      allow(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)
        .and_raise(ArgumentError.new('unexpected error'))

      expect {
        described_class.insert_middleware(app)
      }.to raise_error(ArgumentError, 'unexpected error')
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'logs a warning when the core middleware is absent' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Audience::Middleware).and_return(false)
      # Simulate middleware not found by raising an error on insert_after
      allow(middleware_stack).to receive(:insert_after)
        .with(::Verikloak::Middleware, ::Verikloak::Audience::Middleware)
        .and_raise(RuntimeError.new('No such middleware'))

      logger = instance_double('Logger')
      if defined?(::Rails)
        ::Rails.singleton_class.send(:attr_accessor, :logger) unless ::Rails.respond_to?(:logger=)
        ::Rails.logger = logger
      else
        stub_const('Rails', Module.new)
        Rails.singleton_class.send(:attr_accessor, :logger)
        Rails.logger = logger
      end

      expect(logger).to receive(:warn).with(Verikloak::Audience::RailtieWarnings::WARNING_MESSAGE)

      described_class.insert_middleware(app)
    ensure
      ::Rails.logger = nil if defined?(::Rails) && ::Rails.respond_to?(:logger=)
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'validates configuration after Rails initialization' do
    expect(configuration_initializer).not_to be_nil

    described_class.config.after_initialize_callbacks.clear

    railtie = described_class.new
    # configuration_initializer is [name, options, block]
    expect {
      railtie.instance_eval(&configuration_initializer[2])
    }.to change { described_class.config.after_initialize_callbacks.size }.by(1)

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(config_double).to receive(:required_aud_list).and_return(['rails-api'])
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).to receive(:validate!).and_return(config_double)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
  end

  it 'skips validation during generator commands' do
    expect(configuration_initializer).not_to be_nil

    described_class.config.after_initialize_callbacks.clear

    original_argv = ARGV.dup

    stub_const('Rails::Generators', Module.new)
    ARGV.replace(['generate', 'verikloak:install'])

    railtie = described_class.new
    # configuration_initializer is [name, options, block]
    railtie.instance_eval(&configuration_initializer[2])

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).not_to receive(:validate!)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
    ARGV.replace(original_argv)
  end

  it 'skips validation when only the generator namespace remains in ARGV' do
    expect(configuration_initializer).not_to be_nil

    described_class.config.after_initialize_callbacks.clear

    original_argv = ARGV.dup

    stub_const('Rails::Generators', Module.new)
    ARGV.replace(['verikloak:install'])

    railtie = described_class.new
    # configuration_initializer is [name, options, block]
    railtie.instance_eval(&configuration_initializer[2])

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).not_to receive(:validate!)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
    ARGV.replace(original_argv)
  end

  it 'skips validation for namespaced verikloak install generators' do
    expect(configuration_initializer).not_to be_nil

    described_class.config.after_initialize_callbacks.clear

    original_argv = ARGV.dup

    stub_const('Rails::Generators', Module.new)
    ARGV.replace(['verikloak:pundit:install'])

    railtie = described_class.new
    # configuration_initializer is [name, options, block]
    railtie.instance_eval(&configuration_initializer[2])

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).not_to receive(:validate!)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
    ARGV.replace(original_argv)
  end

  it 'skips validation even before Rails::Generators is loaded' do
    expect(configuration_initializer).not_to be_nil

    described_class.config.after_initialize_callbacks.clear

    original_argv = ARGV.dup

    hide_const('Rails::Generators') if Object.const_defined?(:Rails) && Rails.const_defined?(:Generators)
    ARGV.replace(['generate', 'verikloak:install'])

    railtie = described_class.new
    # configuration_initializer is [name, options, block]
    railtie.instance_eval(&configuration_initializer[2])

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).not_to receive(:validate!)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
    ARGV.replace(original_argv)
  end

  it 'aligns env_claims_key with verikloak-rails configuration when available' do
    original_config = Verikloak::Audience.instance_variable_get(:@config)
    Verikloak::Audience.instance_variable_set(:@config, nil)

    rails_config = Struct.new(:user_env_key, :audience).new('verikloak.custom', nil)
    rails_module = Module.new do
      define_singleton_method(:config) { rails_config }
    end
    stub_const('Verikloak::Rails', rails_module)

    described_class.apply_verikloak_rails_configuration

    expect(Verikloak::Audience.config.env_claims_key).to eq('verikloak.custom')
  ensure
    Verikloak::Audience.instance_variable_set(:@config, original_config)
  end

  it 'derives required_aud and resource_client from verikloak-rails defaults when missing' do
    original_config = Verikloak::Audience.instance_variable_get(:@config)
    Verikloak::Audience.instance_variable_set(:@config, nil)

    rails_config = Struct.new(:user_env_key, :audience).new(nil, ['custom-app'])
    rails_module = Module.new do
      define_singleton_method(:config) { rails_config }
    end
    stub_const('Verikloak::Rails', rails_module)

    described_class.apply_verikloak_rails_configuration

    config = Verikloak::Audience.config
    expect(config.required_aud_list).to eq(['custom-app'])
    expect(config.resource_client).to eq('custom-app')
  ensure
    Verikloak::Audience.instance_variable_set(:@config, original_config)
  end

  it 'syncs skip_paths from verikloak-rails configuration' do
    original_config = Verikloak::Audience.instance_variable_get(:@config)
    Verikloak::Audience.instance_variable_set(:@config, nil)

    rails_config = Struct.new(:user_env_key, :audience, :skip_paths).new(nil, ['rails-api'], ['/up', '/health', '/rails/health'])
    rails_module = Module.new do
      define_singleton_method(:config) { rails_config }
    end
    stub_const('Verikloak::Rails', rails_module)

    described_class.apply_verikloak_rails_configuration

    config = Verikloak::Audience.config
    expect(config.skip_paths).to eq(['/up', '/health', '/rails/health'])
  ensure
    Verikloak::Audience.instance_variable_set(:@config, original_config)
  end

  it 'does not override existing skip_paths configuration' do
    original_config = Verikloak::Audience.instance_variable_get(:@config)
    Verikloak::Audience.instance_variable_set(:@config, nil)

    # Pre-configure skip_paths
    Verikloak::Audience.configure do |cfg|
      cfg.skip_paths = ['/custom/path']
    end

    rails_config = Struct.new(:user_env_key, :audience, :skip_paths).new(nil, ['rails-api'], ['/up', '/health'])
    rails_module = Module.new do
      define_singleton_method(:config) { rails_config }
    end
    stub_const('Verikloak::Rails', rails_module)

    described_class.apply_verikloak_rails_configuration

    config = Verikloak::Audience.config
    expect(config.skip_paths).to eq(['/custom/path'])
  ensure
    Verikloak::Audience.instance_variable_set(:@config, original_config)
  end
end
