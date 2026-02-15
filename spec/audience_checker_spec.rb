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

  it "any_match passes when at least one required audience is present" do
    cfg.profile = :any_match
    cfg.required_aud = ["rails-api", "other-api"]

    # One match is sufficient
    expect(described_class.ok?({ "aud" => ["rails-api"] }, cfg)).to be true
    expect(described_class.ok?({ "aud" => ["other-api"] }, cfg)).to be true
    expect(described_class.ok?({ "aud" => ["rails-api", "other-api"] }, cfg)).to be true

    # Extra audiences are allowed
    expect(described_class.ok?({ "aud" => ["rails-api", "account", "extra"] }, cfg)).to be true

    # No match fails
    expect(described_class.ok?({ "aud" => ["unrelated"] }, cfg)).to be false
    expect(described_class.ok?({ "aud" => [] }, cfg)).to be false
  end

  it "any_match returns false when required_aud is empty" do
    cfg.profile = :any_match
    cfg.required_aud = []
    expect(described_class.ok?({ "aud" => ["anything"] }, cfg)).to be false
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

  describe "normalize_claims observability" do
    let(:poisoned) do
      obj = Object.new
      def obj.to_hash
        raise TypeError, "coercion bomb"
      end
      obj
    end

    it "emits a warn when $DEBUG is enabled and normalize_claims fails" do
      original = $DEBUG
      begin
        $DEBUG = true
        expect {
          described_class.ok?(poisoned, cfg)
        }.to output(/normalize_claims failed.*TypeError.*coercion bomb/).to_stderr
      ensure
        $DEBUG = original
      end
    end

    it "does not emit a warn when $DEBUG is disabled" do
      original = $DEBUG
      begin
        $DEBUG = false
        expect {
          described_class.ok?(poisoned, cfg)
        }.not_to output.to_stderr
      ensure
        $DEBUG = original
      end
    end
  end
end
