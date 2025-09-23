# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'

# Provide a lightweight stub for Rails::Generators::Base so the generator can
# be required without pulling in Rails during the test suite.
unless defined?(Rails::Generators::Base)
  module Rails
    module Generators
      class Base
        class << self
          attr_reader :_source_root

          def source_root(path = nil)
            @_source_root = path if path
            @_source_root
          end

          def desc(*) = nil
          def argument(*) = nil
          def class_option(*) = nil
        end

        attr_reader :destination_root

        def initialize(args = [], options = {}, config = {})
          @destination_root = config[:destination_root] || Dir.pwd
        end

        private

        def template(source, destination)
          source_path = File.expand_path(source, self.class.source_root)
          destination_path = File.expand_path(destination, destination_root)
          FileUtils.mkdir_p(File.dirname(destination_path))
          FileUtils.cp(source_path, destination_path)
        end
      end
    end
  end
end

require 'generators/verikloak/audience/install/install_generator'

RSpec.describe Verikloak::Audience::Generators::InstallGenerator do
  let(:destination_root) { Dir.mktmpdir('verikloak_audience_generator') }

  after do
    FileUtils.remove_entry(destination_root) if File.directory?(destination_root)
  end

  it 'creates an initializer that delegates to the railtie insertion helper' do
    generator = described_class.new([], {}, destination_root: destination_root)
    generator.create_initializer

    initializer_path = File.join(destination_root, 'config/initializers/verikloak_audience.rb')
    expect(File).to exist(initializer_path)

    contents = File.read(initializer_path)
    expect(contents).to include('Verikloak::Audience::Railtie.insert_middleware(Rails.application)')
  end
end
