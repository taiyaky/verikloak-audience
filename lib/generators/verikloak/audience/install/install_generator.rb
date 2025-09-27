# frozen_string_literal: true

begin
  require 'rails/generators'
  require 'rails/generators/base'
rescue LoadError
  raise unless defined?(Rails::Generators::Base)
end

module Verikloak
  module Audience
    module Generators
      # Installs the verikloak audience middleware configuration into a Rails
      # application. This generator creates an initializer that inserts the
      # audience middleware after the core Verikloak middleware once it is
      # available.
      class InstallGenerator < Rails::Generators::Base
        source_root File.expand_path('templates', __dir__)

        def create_initializer
          template 'initializer.rb.erb', 'config/initializers/verikloak_audience.rb'
        end
      end
    end
  end
end
