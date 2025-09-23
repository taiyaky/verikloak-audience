# frozen_string_literal: true

require "spec_helper"
require "verikloak/audience/middleware"

RSpec.describe "Verikloak::Audience::Middleware standalone require" do
  it "loads middleware without requiring the root entrypoint first" do
    app = ->(_env) { [200, {}, ["ok"]] }

    middleware = Verikloak::Audience::Middleware.new(app, required_aud: ["test-aud"])

    expect(middleware).to be_a(Verikloak::Audience::Middleware)
  end

  it "middleware can process requests correctly when loaded standalone" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["success"]] }
    
    middleware = Verikloak::Audience::Middleware.new(
      app,
      required_aud: ["api-client"],
      env_claims_key: "claims",
      profile: :strict_single
    )

    # Valid audience should pass through
    env_with_valid_claims = {
      "claims" => { "aud" => ["api-client"] }
    }
    
    status, _headers, body = middleware.call(env_with_valid_claims)
    expect(status).to eq(200)
    expect(body).to eq(["success"])
  end

  it "middleware rejects invalid audience when loaded standalone" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["success"]] }
    
    middleware = Verikloak::Audience::Middleware.new(
      app,
      required_aud: ["api-client"],
      env_claims_key: "claims",
      profile: :strict_single
    )

    # Invalid audience should be rejected
    env_with_invalid_claims = {
      "claims" => { "aud" => ["wrong-client"] }
    }
    
    status, headers, _body = middleware.call(env_with_invalid_claims)
    expect(status).to eq(403)
    expect(headers["Content-Type"]).to include("application/json")
  end

  it "middleware validates configuration when loaded standalone" do
    app = ->(_env) { [200, {}, ["ok"]] }

    expect {
      Verikloak::Audience::Middleware.new(app, required_aud: [])
    }.to raise_error(Verikloak::Audience::ConfigurationError, /required_aud must include at least one audience/)
  end

  it "middleware works with different profiles when loaded standalone" do
    app = ->(_env) { [200, { "Content-Type" => "text/plain" }, ["success"]] }
    
    # Test allow_account profile
    middleware = Verikloak::Audience::Middleware.new(
      app,
      required_aud: ["api-client"],
      env_claims_key: "claims",
      profile: :allow_account
    )

    # Should accept extra 'account' audience
    env_with_account = {
      "claims" => { "aud" => ["api-client", "account"] }
    }
    
    status, _headers, body = middleware.call(env_with_account)
    expect(status).to eq(200)
    expect(body).to eq(["success"])
  end
end
