# frozen_string_literal: true
require "spec_helper"
require "fileutils"

RSpec.describe 'Verikloak::Audience::Generators::InstallGenerator' do
  before do
    # Provide a fake Rails::Generators base with minimal API
    stub_const('Rails', Module.new)
    stub_const('Rails::Generators', Module.new)

    base_class = Class.new do
      class << self
        def source_root(path = nil)
          @source_root = path if path
          @source_root
        end

        def desc(*); end
        def class_option(*); end
      end

      def initialize(args = [], options = {})
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

    stub_const('Rails::Generators::Base', base_class)

    @added_fake_feature = false
    unless $LOADED_FEATURES.include?('rails/generators')
      $LOADED_FEATURES << 'rails/generators'
      @added_fake_feature = true
    end

    # Load the generator file with the stubs in place
    load File.expand_path('../lib/generators/verikloak/audience/install/install_generator.rb', __dir__)
  end

  after do
    $LOADED_FEATURES.delete('rails/generators') if @added_fake_feature
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
