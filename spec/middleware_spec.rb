# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verikloak::Audience::Middleware do
  include Rack::Test::Methods

  before do
    Verikloak::Audience.configure do |cfg|
      cfg.required_aud = []
      cfg.profile = :strict_single
      cfg.resource_client = Verikloak::Audience::Configuration::DEFAULT_RESOURCE_CLIENT
    end
  end

  let(:inner_app) do
    lambda { |_env| [200, { "Content-Type" => "text/plain" }, ["ok"]] }
  end

  def build_app(opts = {})
    Rack::Builder.new do
      use Verikloak::Audience::Middleware, **opts
      run lambda { |env| [200, { "Content-Type" => "text/plain" }, ["ok"]] }
    end
  end

  it "returns 200 when audience ok (strict_single)" do
    app = build_app(profile: :strict_single, required_aud: ["rails-api"], env_claims_key: "claims")
    res = Rack::MockRequest.new(app).get("/", { "claims" => { "aud" => ["rails-api"] } })
    expect(res.status).to eq 200
    expect(res.body).to eq "ok"
  end

  it "returns 403 with JSON error when audience insufficient" do
    app = build_app(profile: :strict_single, required_aud: ["rails-api"], env_claims_key: "claims")
    res = Rack::MockRequest.new(app).get("/", { "claims" => { "aud" => ["other"] } })
    expect(res.status).to eq 403
    expect(res["Content-Type"]).to include "application/json"
    expect(res.body).to include "insufficient_audience"
  end

  it "logs suggestion when NG and suggest_in_logs enabled" do
    app = build_app(profile: :strict_single, required_aud: ["rails-api"], env_claims_key: "claims", suggest_in_logs: true)
    expect {
      Rack::MockRequest.new(app).get("/", { "claims" => { "aud" => ["rails-api", "account"] } })
    }.to output(/suggestion profile=:allow_account/).to_stderr
  end

  it "prefers rack logger when available" do
    app = build_app(profile: :strict_single, required_aud: ["rails-api"], env_claims_key: "claims", suggest_in_logs: true)
    logger = instance_double("Logger")
    expect(logger).to receive(:warn).with(/insufficient_audience/)
    expect {
      Rack::MockRequest.new(app).get("/", { "claims" => { "aud" => ["account"] }, "rack.logger" => logger })
    }.not_to output.to_stderr
  end

  it "accepts via resource_or_aud when roles exist" do
    app = build_app(profile: :resource_or_aud, required_aud: ["rails-api"], resource_client: "rails-api", env_claims_key: "claims")
    claims = { "resource_access" => { "rails-api" => { "roles" => ["user"] } } }
    res = Rack::MockRequest.new(app).get("/", { "claims" => claims })
    expect(res.status).to eq 200
  end

  it "does not log suggestion when suggest_in_logs is false" do
    app = build_app(profile: :strict_single, required_aud: ["rails-api"], env_claims_key: "claims", suggest_in_logs: false)
    expect {
      Rack::MockRequest.new(app).get("/", { "claims" => { "aud" => ["rails-api", "account"] } })
    }.not_to output.to_stderr
  end

  it "isolates middleware overrides from global configuration" do
    Verikloak::Audience.configure do |cfg|
      cfg.required_aud = ["base"]
    end

    first = described_class.new(inner_app, required_aud: ["override"])
    second = described_class.new(inner_app)

    expect(first.instance_variable_get(:@config).required_aud).to eq(["override"])
    expect(Verikloak::Audience.config.required_aud).to eq(["base"])
    expect(second.instance_variable_get(:@config).required_aud).to eq(["base"])
  ensure
    Verikloak::Audience.configure do |cfg|
      cfg.required_aud = []
    end
  end

  it "treats non-hash claims as missing" do
    app = build_app(profile: :strict_single, required_aud: ["rails-api"], env_claims_key: "claims")
    res = Rack::MockRequest.new(app).get("/", { "claims" => "garbage" })
    expect(res.status).to eq 403
    expect(res.body).to include "insufficient_audience"
  end

  it "reads symbol env keys safely" do
    middleware = described_class.new(inner_app, profile: :strict_single, required_aud: ["rails-api"], env_claims_key: :claims)
    response = middleware.call({ claims: { "aud" => ["rails-api"] } })

    expect(response[0]).to eq(200)
  end

  it "raises when unknown options are provided" do
    expect {
      described_class.new(inner_app, profile: :strict_single, foo: :bar)
    }.to raise_error(Verikloak::Audience::ConfigurationError, /unknown middleware option/)
  end

  it "raises when required_aud is missing" do
    expect {
      described_class.new(inner_app)
    }.to raise_error(Verikloak::Audience::ConfigurationError, /required_aud/)
  end
end
