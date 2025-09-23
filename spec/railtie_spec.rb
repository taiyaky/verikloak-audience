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

      def self.initializer(name, &block)
        entry = [name, block]
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
  let(:app) { instance_double('RailsApp', middleware: middleware_stack) }
  let(:configuration_initializer) do
    Rails::Railtie.initializers.find { |name, _| name == 'verikloak_audience.configuration' }
  end

  it 'inserts after Verikloak::Middleware when defined' do
    begin
      # Define a dummy core middleware constant for the scope of the example
      module ::Verikloak; class Middleware; end; end

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
    allow(middleware_stack).to receive(:include?).and_return(false)
    expect(described_class).not_to receive(:warn_missing_core_middleware)
    expect(middleware_stack).not_to receive(:insert_after)
    described_class.insert_middleware(app)
  end

  it 'does nothing when Verikloak::Middleware is not in the stack' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Middleware).and_return(false)
      expect(described_class).to receive(:warn_missing_core_middleware)
      expect(middleware_stack).not_to receive(:insert_after)

      described_class.insert_middleware(app)
    ensure
      ::Verikloak.send(:remove_const, :Middleware) if defined?(::Verikloak::Middleware)
    end
  end

  it 'logs a warning when the core middleware is absent' do
    begin
      module ::Verikloak; class Middleware; end; end

      allow(middleware_stack).to receive(:include?).with(::Verikloak::Middleware).and_return(false)

      logger = instance_double('Logger')
      if defined?(::Rails)
        ::Rails.singleton_class.send(:attr_accessor, :logger) unless ::Rails.respond_to?(:logger=)
        ::Rails.logger = logger
      else
        stub_const('Rails', Module.new)
        Rails.singleton_class.send(:attr_accessor, :logger)
        Rails.logger = logger
      end

      expect(logger).to receive(:warn).with(described_class::WARNING_MESSAGE)

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
    expect {
      railtie.instance_eval(&configuration_initializer[1])
    }.to change { described_class.config.after_initialize_callbacks.size }.by(1)

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
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
    railtie.instance_eval(&configuration_initializer[1])

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
    railtie.instance_eval(&configuration_initializer[1])

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
    railtie.instance_eval(&configuration_initializer[1])

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
    railtie.instance_eval(&configuration_initializer[1])

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).not_to receive(:validate!)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
    ARGV.replace(original_argv)
  end
end
