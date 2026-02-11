# frozen_string_literal: true

require "json"

module JiraWorklogImport
  module Rollback
    class Store
      DEFAULT_PATH = ".jira_worklog_rollback.json"

      def initialize(path: DEFAULT_PATH)
        @path = path
      end

      # entries: array of { issue_key:, worklog_id:, hash: (optional) }
      def save_run(entries)
        data = {
          "last_run" => entries.map { |e| { "issue_key" => e[:issue_key], "worklog_id" => e[:worklog_id].to_s, "hash" => e[:hash] } },
          "timestamp" => Time.now.iso8601
        }
        File.write(@path, JSON.pretty_generate(data))
      end

      # Returns array of { "issue_key" => ..., "worklog_id" => ..., "hash" => ... } (supports legacy Hash format)
      def load_last_run
        return nil unless File.exist?(@path)

        data = JSON.parse(File.read(@path))
        raw = data["last_run"]
        return nil if raw.nil?

        # New format: array of { issue_key, worklog_id, hash }
        return raw.map { |e| e.transform_keys(&:to_s) } if raw.is_a?(Array)

        # Legacy format: { issue_key => [worklog_id, ...] }
        raw.each_with_object([]) do |(issue_key, ids), arr|
          Array(ids).each { |worklog_id| arr << { "issue_key" => issue_key.to_s, "worklog_id" => worklog_id.to_s, "hash" => nil } }
        end
      rescue JSON::ParserError
        nil
      end
    end
  end
end
