# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Mapping
      attr_reader :issue_key, :date, :time_spent, :comment

      DEFAULT_COLUMNS = {
        "issue_key" => "Issue Key",
        "date" => "Date",
        "time_spent" => "Time Spent",
        "comment" => "Comment"
      }.freeze

      def initialize(issue_key: nil, date: nil, time_spent: nil, comment: nil)
        @issue_key = issue_key || DEFAULT_COLUMNS["issue_key"]
        @date = date || DEFAULT_COLUMNS["date"]
        @time_spent = time_spent || DEFAULT_COLUMNS["time_spent"]
        @comment = comment || DEFAULT_COLUMNS["comment"]
      end

      def self.from_hash(hash)
        new(
          issue_key: hash["issue_key"] || hash[:issue_key],
          date: hash["date"] || hash[:date],
          time_spent: hash["time_spent"] || hash[:time_spent],
          comment: hash["comment"] || hash[:comment]
        )
      end
    end
  end
end
