# frozen_string_literal: true

require "date"

module JiraWorklogImport
  module Mapping
    class WorklogMapper
      def initialize(mapping_config, time_config)
        @mapping = mapping_config
        @time_config = time_config
      end

      def map(row)
        issue_key = value_for(row, @mapping.issue_key)
        date = parse_date(value_for(row, @mapping.date))
        time_spent = value_for(row, @mapping.time_spent)
        comment = value_for(row, @mapping.comment)

        WorklogEntry.new(
          issue_key: issue_key,
          date: date,
          time_spent: time_spent,
          comment: comment,
          source_row: row
        )
      end

      def map_all(rows)
        rows.map { |row| map(row) }
      end

      # Returns the time field hash for the Jira payload:
      # - "minutes" / "hours" / "excel_duration" => { timeSpentSeconds: <integer> }
      # - "jira" => { timeSpent: "<raw string>" } (e.g. "1h 30m"), no conversion
      def time_payload_for(raw_value)
        case @time_config.time_spent_format.to_s.downcase
        when "minutes"
          { timeSpentSeconds: normalize_minutes(raw_value) * 60 }
        when "hours"
          { timeSpentSeconds: (normalize_hours(raw_value) * 3600).to_i }
        when "excel_duration"
          { timeSpentSeconds: parse_excel_duration(raw_value) }
        when "jira"
          { timeSpent: raw_value.to_s.strip }
        else
          # Fallback: treat as minutes
          { timeSpentSeconds: normalize_minutes(raw_value) * 60 }
        end
      end

      private

      def value_for(row, column_name)
        return nil unless column_name

        row[column_name]&.to_s&.strip
      end

      def parse_date(value)
        return nil unless value

        format = @time_config.date_format || "%Y-%m-%d"
        # Use DateTime so time is preserved when format includes %H, %M, %S (e.g. "%Y-%m-%d %H:%M:%S")
        DateTime.strptime(value.to_s.strip, format)
      rescue ArgumentError
        DateTime.parse(value.to_s)
      end

      def normalize_minutes(value)
        n = value.to_s.gsub(/\D/, "").to_i
        n.positive? ? n : 0
      end

      def normalize_hours(value)
        n = value.to_s.gsub(/[^\d.]/, "").to_f
        n.positive? ? n : 0
      end

      # Parses "hh:mm:ss" (Excel duration) to total seconds. Also accepts "mm:ss" (treated as 0:mm:ss).
      def parse_excel_duration(value)
        str = value.to_s.strip
        return 0 if str.empty?

        parts = str.split(":").map { |p| p.gsub(/\D/, "").to_i }
        case parts.size
        when 3
          hours, minutes, seconds = parts
        when 2
          hours = 0
          minutes, seconds = parts
        when 1
          return parts[0] if parts[0].positive?
          return 0
        else
          return 0
        end
        (hours * 3600) + (minutes * 60) + seconds
      end
    end
  end
end
