# frozen_string_literal: true

require "date"

module JiraWorklogImport
  module Mapping
    class WorklogEntry
      attr_reader :issue_key, :date, :time_spent, :comment, :source_row

      def initialize(issue_key:, date:, time_spent:, comment:, source_row: nil)
        @issue_key = issue_key.to_s.strip
        @date = date
        @time_spent = time_spent
        @comment = comment.to_s.strip
        @source_row = source_row
      end

      def to_h
        {
          issue_key: issue_key,
          date: date,
          time_spent: time_spent,
          comment: comment
        }
      end

      # time_field must be either { timeSpentSeconds: <int> } or { timeSpent: "<jira format>" }
      # timezone: optional TZ identifier (e.g. "Europe/Warsaw") for formatting "started"
      def to_jira_payload(time_field, timezone: nil)
        time_field.merge(
          comment: comment.to_s,
          started: jira_started_format(timezone)
        )
      end

      def jira_started_format(timezone = nil)
        d = date.is_a?(String) ? DateTime.parse(date) : date
        if timezone && !timezone.to_s.strip.empty?
          require "tzinfo"
          tz = TZInfo::Timezone.get(timezone.to_s)
          # Date has no public hour/min/sec; DateTime does
          h = d.is_a?(DateTime) ? d.hour : 0
          min = d.is_a?(DateTime) ? d.min : 0
          sec = d.is_a?(DateTime) ? d.sec : 0
          t = tz.local_time(d.year, d.month, d.day, h, min, sec)
          t.strftime("%Y-%m-%dT%H:%M:%S.000%z")
        else
          d.strftime("%Y-%m-%dT%H:%M:%S.000%z")
        end
      end
    end
  end
end
