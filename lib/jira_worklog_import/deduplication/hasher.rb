# frozen_string_literal: true

require "digest"

module JiraWorklogImport
  module Deduplication
    # Tag appended to worklog comments in Jira for deduplication. ID is a short deterministic hash.
    TAG_PREFIX = "[mudd-import-id:"
    TAG_REGEX = /\[mudd-import-id:([a-f0-9]+)\]/

    class Hasher
      DEFAULT_IMPORT_ID_LENGTH = 8

      def hash(entry)
        raw = [
          entry.issue_key.to_s,
          entry.date.to_s,
          entry.time_spent.to_s,
          entry.comment.to_s
        ].join("|")
        Digest::SHA256.hexdigest(raw)
      end

      # Short deterministic id (like a git commit hash) for tagging worklogs in Jira.
      def import_id(entry, length: DEFAULT_IMPORT_ID_LENGTH)
        hash(entry)[0, length]
      end
    end
  end
end
