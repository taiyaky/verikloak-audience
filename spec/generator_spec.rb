# frozen_string_literal: true
require "spec_helper"
require "fileutils"

RSpec.describe 'Verikloak::Audience::Generators::InstallGenerator' do
  before do
    # Provide a fake Rails::Generators base with minimal API
    base_class = Class.new do
      class << self
        def source_root(path = nil)
          @source_root = path if path
          @source_root
        end

        def desc(*); end
        def class_option(*); end
      end

      def initialize(_args = [], options = {})
        @options = options
      end

      def options
        @options || {}
      end

      def template(src, dest)
        src_path = File.join(self.class.source_root, src)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.cp(src_path, dest)
      end
    end

    stub_const('Rails', Module.new)
    stub_const('Rails::Generators', Module.new)
    stub_const('Rails::Generators::Base', base_class)

    original_require = Kernel.instance_method(:require)
    allow_any_instance_of(Object).to receive(:require) do |instance, path|
      if path == 'rails/generators'
        true
      else
        original_require.bind(instance).call(path)
      end
    end

    if defined?(Verikloak::Audience::Generators::InstallGenerator)
      Verikloak::Audience::Generators.send(:remove_const, :InstallGenerator)
    end

    load File.expand_path('../lib/generators/verikloak/audience/install/install_generator.rb', __dir__)
  end

  it "creates initializer" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        gen = Verikloak::Audience::Generators::InstallGenerator.new
        gen.create_initializer

        expect(File).to exist('config/initializers/verikloak_audience.rb')
      end
    end
  end
end
