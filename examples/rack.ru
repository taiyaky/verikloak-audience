# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'rack'
require 'json'
require 'verikloak/audience'

# Dummy app to show 200 when audience OK
app = Rack::Builder.new do
  use Verikloak::Audience::Middleware,
      profile: :allow_account,
      required_aud: ['rails-api'],
      resource_client: 'rails-api',
      env_claims_key: 'verikloak.user',
      suggest_in_logs: true

  run lambda { |_env|
    [200, { 'Content-Type' => 'application/json' }, [{ ok: true }.to_json]]
  }
end

run app
