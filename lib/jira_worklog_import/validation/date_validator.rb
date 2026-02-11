# frozen_string_literal: true

require "date"

module JiraWorklogImport
  module Validation
    class DateValidator < Base
      def initialize(allow_future: false)
        @allow_future = allow_future
      end

      def validate(entry)
        date = entry.date
        raise Error.new("Date is missing", entry: entry, validator_name: "DateValidator") unless date

        d = date.is_a?(Date) ? date : Date.parse(date.to_s)
        return if @allow_future
        # Compare calendar date only so "today" at any time is not considered future
        date_only = d.respond_to?(:to_date) ? d.to_date : d
        return unless date_only > Date.today

        raise Error.new(
          "Date cannot be in the future: #{date_only}",
          entry: entry,
          validator_name: "DateValidator"
        )
      end
    end
  end
end
