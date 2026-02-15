# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Verikloak::Audience.reset!" do
  after { Verikloak::Audience.reset! }

  it "resets configuration to defaults" do
    Verikloak::Audience.configure do |cfg|
      cfg.required_aud = ["custom-api"]
      cfg.profile = :any_match
      cfg.resource_client = "custom-client"
    end

    expect(Verikloak::Audience.config.required_aud).to eq(["custom-api"])
    expect(Verikloak::Audience.config.profile).to eq(:any_match)

    Verikloak::Audience.reset!

    config = Verikloak::Audience.config
    expect(config.required_aud).to eq(Verikloak::Audience::Configuration.new.required_aud)
    expect(config.profile).to eq(Verikloak::Audience::Configuration.new.profile)
    expect(config.resource_client).to eq(Verikloak::Audience::Configuration::DEFAULT_RESOURCE_CLIENT)
  end

  it "prevents configuration leakage between examples (part 1: set)" do
    Verikloak::Audience.configure { |c| c.required_aud = ["leaked-api"] }
    expect(Verikloak::Audience.config.required_aud).to eq(["leaked-api"])
  end

  it "prevents configuration leakage between examples (part 2: verify)" do
    # after block in part 1 called reset!, so config should be fresh defaults
    expect(Verikloak::Audience.config.required_aud).not_to eq(["leaked-api"])
  end
end
