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

  it 'inserts after Verikloak::Middleware when defined' do
    begin
      # Define a dummy core middleware constant for the scope of the example
      module ::Verikloak; class Middleware; end; end

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
    expect(middleware_stack).not_to receive(:insert_after)
    described_class.insert_middleware(app)
  end

  it 'validates configuration after Rails initialization' do
    initializer = Rails::Railtie.initializers.find { |name, _| name == 'verikloak_audience.configuration' }
    expect(initializer).not_to be_nil

    described_class.config.after_initialize_callbacks.clear

    railtie = described_class.new
    expect {
      railtie.instance_eval(&initializer[1])
    }.to change { described_class.config.after_initialize_callbacks.size }.by(1)

    callback = described_class.config.after_initialize_callbacks.last
    config_double = instance_double(Verikloak::Audience::Configuration)
    allow(Verikloak::Audience).to receive(:config).and_return(config_double)
    expect(config_double).to receive(:validate!).and_return(config_double)

    callback.call
  ensure
    described_class.config.after_initialize_callbacks.clear
  end
end
