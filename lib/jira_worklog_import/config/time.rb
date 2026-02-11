# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Time
      attr_reader :date_format, :time_spent_format, :timezone

      DEFAULT_TIMEZONE = "Europe/Warsaw"

      def initialize(date_format: "%Y-%m-%d", time_spent_format: "minutes", timezone: DEFAULT_TIMEZONE)
        @date_format = date_format
        @time_spent_format = time_spent_format # minutes, hours, or jira (e.g. "1h 30m")
        s = timezone.to_s.strip
        @timezone = s.empty? ? DEFAULT_TIMEZONE : s
      end

      def self.from_hash(hash)
        new(
          date_format: hash["date_format"] || hash[:date_format],
          time_spent_format: hash["time_spent_format"] || hash[:time_spent_format],
          timezone: hash["timezone"] || hash[:timezone]
        )
      end
    end
  end
end
