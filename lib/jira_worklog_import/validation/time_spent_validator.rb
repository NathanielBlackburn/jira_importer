# frozen_string_literal: true

module JiraWorklogImport
  module Validation
    class TimeSpentValidator < Base
      def validate(entry)
        raw = entry.time_spent.to_s
        return if raw.match?(/\d/) && numeric_positive?(raw)

        raise Error.new(
          "Time spent must be greater than 0: #{entry.time_spent.inspect}",
          entry: entry,
          validator_name: "TimeSpentValidator"
        )
      end

      private

      def numeric_positive?(raw)
        n = raw.gsub(/[^\d.]/, "").to_f
        n.positive?
      end
    end
  end
end
