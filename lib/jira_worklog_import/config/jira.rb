# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Jira
      attr_reader :base_url

      def initialize(base_url: nil)
        @base_url = base_url || ENV["JIRA_BASE_URL"] || ""
      end

      def self.from_hash(hash)
        new(
          base_url: hash["base_url"] || hash[:base_url]
        )
      end
    end
  end
end
