# frozen_string_literal: true

require 'spec_helper'

# Provide a minimal Rails::Railtie stub and mark it as loaded so that
# requiring the gem's railtie file does not attempt to load the real Rails.
unless defined?(Rails::Railtie)
  module Rails
    class Railtie
      def self.initializers
        @initializers ||= []
      end

      def self.initializer(name, &block)
        initializers << [name, block]
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
end
