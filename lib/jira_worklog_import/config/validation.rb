# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Validation
      attr_reader :enabled, :issue_key_pattern, :allow_future_dates

      def initialize(enabled: true, issue_key_pattern: nil, allow_future_dates: false)
        @enabled = enabled
        @issue_key_pattern = issue_key_pattern || /\A[A-Z][A-Z0-9]+-\d+\z/
        @allow_future_dates = allow_future_dates
      end

      def self.from_hash(hash)
        pattern = hash["issue_key_pattern"] || hash[:issue_key_pattern]
        new(
          enabled: hash.key?("enabled") ? hash["enabled"] : (hash.key?(:enabled) ? hash[:enabled] : true),
          issue_key_pattern: pattern ? Regexp.new(pattern) : nil,
          allow_future_dates: hash["allow_future_dates"] || hash[:allow_future_dates] || false
        )
      end
    end
  end
end
