# frozen_string_literal: true

require 'rails/generators'

module Verikloak
  module Audience
    module Generators
      # Installs the verikloak audience middleware configuration into a Rails
      # application. This generator creates an initializer that inserts the
      # audience middleware after the core Verikloak middleware once it is
      # available.
      class InstallGenerator < ::Rails::Generators::Base
        source_root File.expand_path('templates', __dir__)

        desc 'Creates an initializer for verikloak-audience middleware integration.'

        def create_initializer
          template 'initializer.rb.erb', 'config/initializers/verikloak_audience.rb'
        end
      end
    end
  end
end
