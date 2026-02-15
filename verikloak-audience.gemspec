# frozen_string_literal: true

require_relative 'lib/verikloak/audience/version'

Gem::Specification.new do |spec|
  spec.name          = 'verikloak-audience'
  spec.version       = Verikloak::Audience::VERSION
  spec.authors       = ['taiyaky']

  spec.summary       = 'Audience profiles for Keycloak on top of Verikloak'
  spec.description   = <<~DESC
    Rack middleware that enforces audience checks with deployable profiles,
    layering on top of Verikloak token verification.
  DESC

  spec.homepage      = 'https://github.com/taiyaky/verikloak-audience'
  spec.license       = 'MIT'

  spec.files         = Dir['lib/**/*.{rb,erb}'] + %w[README.md LICENSE CHANGELOG.md]
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 3.1'

  # Runtime dependencies
  spec.add_dependency 'rack', '>= 2.2', '< 4.0'
  spec.add_dependency 'verikloak', '~> 1.0'

  # Metadata for RubyGems
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri']   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['documentation_uri'] = "https://rubydoc.info/gems/verikloak-audience/#{Verikloak::Audience::VERSION}"
  spec.metadata['rubygems_mfa_required'] = 'true'
end
