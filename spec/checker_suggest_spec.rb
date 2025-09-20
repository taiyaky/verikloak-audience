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
end

