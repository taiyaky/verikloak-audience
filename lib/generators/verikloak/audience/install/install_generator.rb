# frozen_string_literal: true

begin
  require 'rails/generators'
  require 'rails/generators/base'
rescue LoadError
  # Allow the generator to be required without Rails.
end

module Verikloak
  module Audience
    module Generators
      # Installs the verikloak audience middleware configuration into a Rails
      # application. This generator creates an initializer that inserts the
      # audience middleware after the core Verikloak middleware once it is
      # available.
      class InstallGenerator < (defined?(Rails::Generators::Base) ? Rails::Generators::Base : Object)
        source_root File.expand_path('templates', __dir__) if respond_to?(:source_root)

        def create_initializer
          return unless respond_to?(:template, true)

          template 'verikloak_audience.rb.tt', 'config/initializers/verikloak_audience.rb'
        end
      end
    end
  end
end
