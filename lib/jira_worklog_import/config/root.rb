# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Root
      attr_reader :jira, :csv, :mapping, :time, :validation, :deduplication, :rate_limit

      def initialize(jira:, csv:, mapping:, time:, validation:, deduplication:, rate_limit:)
        @jira = jira
        @csv = csv
        @mapping = mapping
        @time = time
        @validation = validation
        @deduplication = deduplication
        @rate_limit = rate_limit
      end
    end
  end
end
