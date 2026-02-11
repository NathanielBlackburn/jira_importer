# frozen_string_literal: true

require "spec_helper"

RSpec.describe JiraWorklogImport::Mapping::WorklogMapper do
  let(:mapping_config) { JiraWorklogImport::Config::Mapping.from_hash({}) }
  let(:time_config) { JiraWorklogImport::Config::Time.from_hash(format_hash) }
  let(:format_hash) { {} }
  let(:mapper) { described_class.new(mapping_config, time_config) }

  describe "#time_payload_for" do
    context "when time_spent_format is 'minutes'" do
      let(:format_hash) { { "time_spent_format" => "minutes" } }

      it "converts minutes to timeSpentSeconds" do
        expect(mapper.time_payload_for("60")).to eq({ timeSpentSeconds: 3600 })
      end

      it "strips non-digits and converts" do
        expect(mapper.time_payload_for("90 min")).to eq({ timeSpentSeconds: 5400 })
      end

      it "handles zero" do
        expect(mapper.time_payload_for("0")).to eq({ timeSpentSeconds: 0 })
      end
    end

    context "when time_spent_format is 'hours'" do
      let(:format_hash) { { "time_spent_format" => "hours" } }

      it "converts hours to timeSpentSeconds" do
        expect(mapper.time_payload_for("1")).to eq({ timeSpentSeconds: 3600 })
      end

      it "handles fractional hours" do
        expect(mapper.time_payload_for("1.5")).to eq({ timeSpentSeconds: 5400 })
      end

      it "strips non-numeric characters" do
        expect(mapper.time_payload_for("2h")).to eq({ timeSpentSeconds: 7200 })
      end
    end

    context "when time_spent_format is 'jira'" do
      let(:format_hash) { { "time_spent_format" => "jira" } }

      it "passes value through as timeSpent without conversion" do
        expect(mapper.time_payload_for("1h 30m")).to eq({ timeSpent: "1h 30m" })
      end

      it "strips surrounding whitespace" do
        expect(mapper.time_payload_for("  2h 15m  ")).to eq({ timeSpent: "2h 15m" })
      end
    end

    context "when time_spent_format is 'excel_duration'" do
      let(:format_hash) { { "time_spent_format" => "excel_duration" } }

      it "parses hh:mm:ss to timeSpentSeconds" do
        expect(mapper.time_payload_for("1:00:00")).to eq({ timeSpentSeconds: 3600 })
      end

      it "parses 1:30:00 as 1h 30m in seconds" do
        expect(mapper.time_payload_for("1:30:00")).to eq({ timeSpentSeconds: 5400 })
      end

      it "parses mm:ss as 0:mm:ss" do
        expect(mapper.time_payload_for("45:00")).to eq({ timeSpentSeconds: 2700 })
      end

      it "parses 0:00:30 as 30 seconds" do
        expect(mapper.time_payload_for("0:00:30")).to eq({ timeSpentSeconds: 30 })
      end

      it "handles leading zeros" do
        expect(mapper.time_payload_for("01:30:00")).to eq({ timeSpentSeconds: 5400 })
      end
    end

    context "when time_spent_format is unknown (fallback)" do
      let(:format_hash) { { "time_spent_format" => "unknown" } }

      it "treats value as minutes" do
        expect(mapper.time_payload_for("30")).to eq({ timeSpentSeconds: 1800 })
      end
    end
  end
end
