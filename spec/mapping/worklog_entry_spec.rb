# frozen_string_literal: true

require "spec_helper"
require "date"

RSpec.describe JiraWorklogImport::Mapping::WorklogEntry do
  let(:entry) do
    described_class.new(
      issue_key: "PROJ-1",
      date: Date.new(2025, 2, 1),
      time_spent: "60",
      comment: "Did some work"
    )
  end

  describe "#to_h" do
    it "returns a hash of attributes" do
      expect(entry.to_h).to eq(
        issue_key: "PROJ-1",
        date: Date.new(2025, 2, 1),
        time_spent: "60",
        comment: "Did some work"
      )
    end
  end

  describe "#to_jira_payload" do
    it "merges time field (timeSpentSeconds or timeSpent), plain string comment, and started" do
      payload = entry.to_jira_payload({ timeSpentSeconds: 3600 })
      expect(payload[:timeSpentSeconds]).to eq(3600)
      expect(payload[:started]).to match(/\A2025-02-01T/)
      expect(payload[:comment]).to eq("Did some work")
    end

    it "accepts timeSpent (Jira format) instead of timeSpentSeconds" do
      payload = entry.to_jira_payload({ timeSpent: "1h 30m" })
      expect(payload[:timeSpent]).to eq("1h 30m")
      expect(payload[:comment]).to eq("Did some work")
    end

    it "accepts optional timezone and uses it for started" do
      payload = entry.to_jira_payload({ timeSpentSeconds: 3600 }, timezone: "Europe/Warsaw")
      expect(payload[:started]).to match(/\A2025-02-01T00:00:00\.000\+0100\z/)
    end
  end

  describe "#jira_started_format" do
    context "without timezone" do
      it "formats date as ISO with default offset" do
        entry = described_class.new(
          issue_key: "X",
          date: DateTime.new(2025, 2, 1, 14, 30, 0),
          time_spent: "60",
          comment: "Work"
        )
        result = entry.jira_started_format(nil)
        expect(result).to match(/\A2025-02-01T14:30:00\.000/)
      end
    end

    context "with timezone Europe/Warsaw" do
      it "formats date in Warsaw time with correct offset (CET = +0100 in winter)" do
        entry = described_class.new(
          issue_key: "X",
          date: DateTime.new(2025, 2, 1, 12, 0, 0),
          time_spent: "60",
          comment: "Work"
        )
        result = entry.jira_started_format("Europe/Warsaw")
        expect(result).to eq("2025-02-01T12:00:00.000+0100")
      end

      it "formats datetime with time component preserved" do
        entry = described_class.new(
          issue_key: "X",
          date: DateTime.new(2026, 2, 10, 19, 0, 0),
          time_spent: "60",
          comment: "Work"
        )
        result = entry.jira_started_format("Europe/Warsaw")
        expect(result).to eq("2026-02-10T19:00:00.000+0100")
      end

      it "formats date in Warsaw with correct offset in summer (CEST = +0200)" do
        entry = described_class.new(
          issue_key: "X",
          date: DateTime.new(2025, 7, 15, 14, 30, 0),
          time_spent: "60",
          comment: "Work"
        )
        result = entry.jira_started_format("Europe/Warsaw")
        expect(result).to eq("2025-07-15T14:30:00.000+0200")
      end
    end

    context "with timezone UTC" do
      it "formats with +0000 offset" do
        entry = described_class.new(
          issue_key: "X",
          date: DateTime.new(2025, 2, 1, 12, 0, 0),
          time_spent: "60",
          comment: "Work"
        )
        result = entry.jira_started_format("UTC")
        expect(result).to eq("2025-02-01T12:00:00.000+0000")
      end
    end

    context "with blank timezone" do
      it "falls back to non-timezone formatting" do
        entry = described_class.new(
          issue_key: "X",
          date: DateTime.new(2025, 2, 1, 12, 0, 0),
          time_spent: "60",
          comment: "Work"
        )
        result = entry.jira_started_format("")
        expect(result).to match(/\A2025-02-01T12:00:00\.000/)
      end
    end
  end
end
