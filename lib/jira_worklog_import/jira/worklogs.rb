# frozen_string_literal: true

require "set"

module JiraWorklogImport
  module Jira
    class Worklogs
      def initialize(client)
        @client = client
      end

      def add(issue_key, payload)
        @client.create_worklog(issue_key, payload)
      end

      def issue_exists?(issue_key)
        @client.issue_exists?(issue_key)
      end

      # Returns Set of mudd-import-id values found in the issue's worklog comments (for deduplication).
      def existing_import_ids(issue_key)
        return Set.new unless defined?(JiraWorklogImport::Deduplication::TAG_REGEX)

        worklogs = @client.get_worklogs(issue_key)
        ids = Set.new
        worklogs.each do |wl|
          comment = wl["comment"].to_s
          comment.scan(JiraWorklogImport::Deduplication::TAG_REGEX) { ids << Regexp.last_match(1) }
        end
        ids
      end
    end
  end
end
