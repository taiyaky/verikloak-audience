# frozen_string_literal: true

require "spec_helper"

RSpec.describe Verikloak::Audience::Configuration do
  it "converts required_aud to string array" do
    cfg = described_class.new
    cfg.required_aud = :service
    expect(cfg.required_aud_list).to eq ["service"]

    cfg.required_aud = ["a", :b]
    expect(cfg.required_aud_list).to eq ["a", "b"]
  end

  it "has safe defaults" do
    cfg = described_class.new
    expect(cfg.profile).to eq :strict_single
    expect(cfg.env_claims_key).to eq "verikloak.user"
    expect(cfg.suggest_in_logs).to be true
  end

  it "duplicates mutable attributes when copied" do
    cfg = described_class.new
    cfg.profile = "strict_single"
    cfg.required_aud = ["base"]
    cfg.resource_client = "api"
    cfg.env_claims_key = "claims"

    duped = cfg.dup
    duped.profile.replace("allow_account")
    duped.required_aud << "extra"
    duped.resource_client.replace("other")
    duped.env_claims_key.replace("other.claims")

    expect(cfg.profile).to eq "strict_single"
    expect(cfg.required_aud).to eq ["base"]
    expect(cfg.resource_client).to eq "api"
    expect(cfg.env_claims_key).to eq "claims"
  end

  it "normalizes env_claims_key to strings" do
    cfg = described_class.new
    cfg.env_claims_key = :claims

    expect(cfg.env_claims_key).to eq("claims")
  end

  describe "#validate!" do
    it "raises when required_aud is empty" do
      cfg = described_class.new
      cfg.required_aud = []

      expect { cfg.validate! }.to raise_error(Verikloak::Audience::ConfigurationError)
    end

    it "infers resource_client from required_aud when profile resource_or_aud" do
      cfg = described_class.new
      cfg.profile = :resource_or_aud
      cfg.required_aud = ['bff-api']
      cfg.resource_client = described_class::DEFAULT_RESOURCE_CLIENT

      expect(cfg.validate!.resource_client).to eq('bff-api')
    end

    it "raises when resource_client is not in required_aud" do
      cfg = described_class.new
      cfg.profile = :resource_or_aud
      cfg.required_aud = %w[first second]
      cfg.resource_client = 'other'

      expect { cfg.validate! }.to raise_error(Verikloak::Audience::ConfigurationError,
                                              /resource_client must match one of required_aud/)
    end
  end
end

