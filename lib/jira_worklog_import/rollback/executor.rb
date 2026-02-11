# frozen_string_literal: true

module JiraWorklogImport
  module Rollback
    class Executor
      def initialize(jira_client, store, deduplication_store: nil, on_rollback: nil)
        @client = jira_client
        @store = store
        @deduplication_store = deduplication_store
        @on_rollback = on_rollback
      end

      def rollback_last_run
        run = @store.load_last_run
        return { deleted: 0, errors: [], hashes_cleared: 0 } unless run

        deleted = 0
        errors = []
        hashes_cleared = 0
        run.each do |entry|
          issue_key = entry["issue_key"]
          worklog_id = entry["worklog_id"]
          hash = entry["hash"]
          start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          delete_worklog(issue_key, worklog_id)
          duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
          deleted += 1
          @on_rollback&.call(issue_key, worklog_id, duration)
          if hash && @deduplication_store
            @deduplication_store.remove(hash)
            hashes_cleared += 1
          end
        rescue Jira::Error => e
          errors << { issue_key: issue_key, worklog_id: worklog_id, error: e.message }
        end
        @store.save_run([]) if errors.empty?
        { deleted: deleted, errors: errors, hashes_cleared: hashes_cleared }
      end

      private

      def delete_worklog(issue_key, worklog_id)
        @client.delete_worklog(issue_key, worklog_id)
      end
    end
  end
end
