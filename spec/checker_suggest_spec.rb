# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verikloak::Audience::Checker do
  let(:cfg) do
    Verikloak::Audience::Configuration.new.tap do |c|
      c.required_aud = ["rails-api"]
      c.resource_client = "rails-api"
    end
  end

  it "suggests :strict_single when exact match" do
    claims = { "aud" => ["rails-api"] }
    expect(described_class.suggest(claims, cfg)).to eq :strict_single
  end

  it "suggests :allow_account when only extra is 'account'" do
    claims = { "aud" => ["rails-api", "account"] }
    expect(described_class.suggest(claims, cfg)).to eq :allow_account
  end

  it "suggests :resource_or_aud when roles exist" do
    claims = { "resource_access" => { "rails-api" => { "roles" => ["x"] } } }
    expect(described_class.suggest(claims, cfg)).to eq :resource_or_aud
  end

  it "suggests :any_match when one of several required audiences is present" do
    cfg.required_aud = ["rails-api", "other-api"]
    claims = { "aud" => ["rails-api", "unrelated"] }
    expect(described_class.suggest(claims, cfg)).to eq :any_match
  end

  it "falls back to :strict_single by default when no profile accepts the claims" do
    claims = { "aud" => ["unrelated"] }
    expect(described_class.suggest(claims, cfg)).to eq :strict_single
  end

  it "returns the given fallback when no profile accepts the claims" do
    claims = { "aud" => ["unrelated"] }
    expect(described_class.suggest(claims, cfg, fallback: nil)).to be_nil
  end
end

