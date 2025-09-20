# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verikloak::Audience::Checker do
  let(:cfg) do
    Verikloak::Audience::Configuration.new.tap do |c|
      c.required_aud = ["rails-api"]
      c.resource_client = "rails-api"
    end
  end

  it "strict_single requires exact match" do
    cfg.profile = :strict_single
    claims = { "aud" => ["rails-api"] }
    expect(described_class.ok?(claims, cfg)).to be true

    claims = { "aud" => ["rails-api", "account"] }
    expect(described_class.ok?(claims, cfg)).to be false
  end

  it "allow_account tolerates extra 'account'" do
    cfg.profile = :allow_account
    claims = { "aud" => ["rails-api", "account"] }
    expect(described_class.ok?(claims, cfg)).to be true
  end

  it "strict_single returns false when required_aud is empty" do
    cfg.profile = :strict_single
    cfg.required_aud = []
    expect(described_class.ok?({ "aud" => ["anything"] }, cfg)).to be false
    expect(described_class.ok?({ "aud" => [] }, cfg)).to be false
  end

  it "resource_or_aud passes when resource roles exist" do
    cfg.profile = :resource_or_aud
    claims = { "resource_access" => { "rails-api" => { "roles" => ["editor"] } } }
    expect(described_class.ok?(claims, cfg)).to be true
  end

  it "strict_single matches multiple audiences order-insensitively" do
    cfg.profile = :strict_single
    cfg.required_aud = ["a", "b"]
    expect(described_class.ok?({ "aud" => ["b", "a"] }, cfg)).to be true
  end

  it "allow_account rejects unknown extras besides 'account'" do
    cfg.profile = :allow_account
    claims = { "aud" => ["rails-api", "account", "other"] }
    expect(described_class.ok?(claims, cfg)).to be false
  end

  it "resource_or_aud falls back to allow_account when no roles" do
    cfg.profile = :resource_or_aud
    cfg.required_aud = ["rails-api"]
    claims = { "aud" => ["rails-api", "account"] }
    expect(described_class.ok?(claims, cfg)).to be true
  end

  it "defaults to strict_single when profile is nil" do
    cfg.profile = nil
    claims = { "aud" => ["rails-api"] }
    expect(described_class.ok?(claims, cfg)).to be true
  end

  it "raises when profile is not recognized" do
    cfg.profile = :unknown_profile
    expect {
      described_class.ok?({ "aud" => ["rails-api"] }, cfg)
    }.to raise_error(Verikloak::Audience::ConfigurationError, /unknown audience profile/)
  end

  it "treats non-hash claims as empty when evaluating" do
    cfg.profile = :resource_or_aud
    expect(described_class.ok?("not a hash", cfg)).to be false
  end

  it "treats non-hash claims as empty when suggesting" do
    expect(described_class.suggest("invalid", cfg)).to eq(:strict_single)
  end
end
