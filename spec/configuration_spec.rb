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
end

