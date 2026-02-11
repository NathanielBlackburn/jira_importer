# frozen_string_literal: true

module JiraWorklogImport
  module Validation
    class IssueKeyValidator < Base
      def initialize(pattern: /\A[A-Z][A-Z0-9]+-\d+\z/)
        @pattern = pattern
      end

      def validate(entry)
        key = entry.issue_key.to_s
        return if key.match?(@pattern)

        raise Error.new(
          "Invalid Jira issue key: #{key.inspect}",
          entry: entry,
          validator_name: "IssueKeyValidator"
        )
      end
    end
  end
end
