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

  it "creates initializer with expected content at the default location" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        generator = Verikloak::Audience::Generators::InstallGenerator.new
        generator.create_initializer

        path = 'config/initializers/verikloak_audience.rb'
        expect(File).to exist(path)
        
        initializer_content = File.read(path)
        expect(initializer_content).to include('Verikloak::Audience::Railtie')
        expect(initializer_content).to include('Verikloak::Audience::Railtie.insert_middleware')
        expect(initializer_content).to include('Rails.application')
        expect(initializer_content).to include('frozen_string_literal: true')
      end
    end
  end

  it "creates the initializer with all expected content sections" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        gen = Verikloak::Audience::Generators::InstallGenerator.new
        gen.create_initializer

        initializer_content = File.read('config/initializers/verikloak_audience.rb')

        expect(initializer_content).to include('defined?(Rails)')
        expect(initializer_content).to include('Rails.respond_to?(:application)')
        expect(initializer_content).to include('frozen_string_literal: true')
      end
    end
  end

  it "creates config directory structure when it doesn't exist" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        gen = Verikloak::Audience::Generators::InstallGenerator.new
        gen.create_initializer

        expect(Dir).to exist('config/initializers')
      end
    end
  end

  context "error handling" do
    it "handles missing template file gracefully" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          # Temporarily change source_root to simulate missing template
          fake_source_root = File.join(dir, 'fake_templates')
          
          # Override the source_root class method
          allow(Verikloak::Audience::Generators::InstallGenerator).to receive(:source_root).and_return(fake_source_root)
          
          generator = Verikloak::Audience::Generators::InstallGenerator.new
          
          expect { generator.create_initializer }.to raise_error(Errno::ENOENT)
        end
      end
    end

    it "raises an error when destination directory cannot be created due to file conflict" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          # Create a file with the same name as the directory we want to create
          FileUtils.touch('config')
          
          generator = Verikloak::Audience::Generators::InstallGenerator.new
          
          expect { generator.create_initializer }.to raise_error(Errno::EEXIST)
        end
      end
    end
  end
end
