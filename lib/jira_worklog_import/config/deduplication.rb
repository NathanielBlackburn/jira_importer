# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Deduplication
      attr_reader :enabled, :store_path

      def initialize(enabled: false, store_path: ".jira_worklog_hashes.json")
        @enabled = enabled
        @store_path = store_path
      end

      def self.from_hash(hash)
        new(
          enabled: hash["enabled"] || hash[:enabled] || false,
          store_path: hash["store_path"] || hash[:store_path] || ".jira_worklog_hashes.json"
        )
      end
    end
  end
end
