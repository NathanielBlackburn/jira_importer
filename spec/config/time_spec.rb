# frozen_string_literal: true

require "spec_helper"

RSpec.describe JiraWorklogImport::Config::Time do
  describe "default timezone" do
    it "defaults to Europe/Warsaw when not specified" do
      config = described_class.new
      expect(config.timezone).to eq("Europe/Warsaw")
    end

    it "uses DEFAULT_TIMEZONE constant" do
      expect(described_class::DEFAULT_TIMEZONE).to eq("Europe/Warsaw")
    end
  end

  describe ".from_hash" do
    it "loads timezone from hash (string keys)" do
      config = described_class.from_hash("timezone" => "America/New_York")
      expect(config.timezone).to eq("America/New_York")
    end

    it "loads timezone from hash (symbol keys)" do
      config = described_class.from_hash(timezone: "Asia/Tokyo")
      expect(config.timezone).to eq("Asia/Tokyo")
    end

    it "defaults to Europe/Warsaw when timezone is missing" do
      config = described_class.from_hash({})
      expect(config.timezone).to eq("Europe/Warsaw")
    end

    it "uses default when timezone is blank string" do
      config = described_class.new(timezone: "   ")
      expect(config.timezone).to eq("Europe/Warsaw")
    end

    it "strips whitespace from timezone" do
      config = described_class.from_hash("timezone" => "  Europe/London  ")
      expect(config.timezone).to eq("Europe/London")
    end
  end
end
