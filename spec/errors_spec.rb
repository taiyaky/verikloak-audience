# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Verikloak::Audience error classes" do
  describe Verikloak::Audience::Error do
    it "inherits from Verikloak::Error for uniform rescue across the gem family" do
      expect(described_class.ancestors).to include(Verikloak::Error)
    end

    it "exposes default code, message, and http_status" do
      error = described_class.new
      expect(error.message).to eq("audience error")
      expect(error.code).to eq("audience_error")
      expect(error.http_status).to eq(403)
    end

    it "accepts custom code and http_status" do
      error = described_class.new("boom", code: "custom_code", http_status: 418)
      expect(error.message).to eq("boom")
      expect(error.code).to eq("custom_code")
      expect(error.http_status).to eq(418)
    end
  end

  describe Verikloak::Audience::Forbidden do
    it "defaults to the insufficient_audience code with 403" do
      error = described_class.new
      expect(error.message).to eq("insufficient audience")
      expect(error.code).to eq("insufficient_audience")
      expect(error.http_status).to eq(403)
    end

    it "preserves the code and status when given a custom message" do
      error = described_class.new("audience mismatch for client X")
      expect(error.message).to eq("audience mismatch for client X")
      expect(error.code).to eq("insufficient_audience")
      expect(error.http_status).to eq(403)
    end

    it "is rescuable as Verikloak::Audience::Error and Verikloak::Error" do
      expect { raise described_class }.to raise_error(Verikloak::Audience::Error)
      expect { raise described_class }.to raise_error(Verikloak::Error)
    end
  end

  describe Verikloak::Audience::ConfigurationError do
    it "defaults to the audience_configuration_error code with 500" do
      error = described_class.new
      expect(error.message).to eq("invalid audience configuration")
      expect(error.code).to eq("audience_configuration_error")
      expect(error.http_status).to eq(500)
    end
  end
end
