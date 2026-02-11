# frozen_string_literal: true

require "json"

module JiraWorklogImport
  module Reporting
    class Report
      attr_reader :imported, :skipped, :failed

      def initialize
        @imported = []
        @skipped = []
        @failed = []
      end

      def add_imported(entry, worklog_id = nil)
        @imported << { entry: entry, worklog_id: worklog_id }
      end

      def add_skipped(entry, reason)
        @skipped << { entry: entry, reason: reason }
      end

      def add_failed(entry, error)
        @failed << { entry: entry, error: error }
      end

      def summary
        {
          imported: @imported.size,
          skipped: @skipped.size,
          failed: @failed.size
        }
      end

      def to_json(*args)
        h = {
          summary: summary,
          imported: @imported.map { |x| { worklog_id: x[:worklog_id], entry: x[:entry].to_h } },
          skipped: @skipped.map { |x| { reason: x[:reason], entry: x[:entry].to_h } },
          failed: @failed.map { |x| { error: x[:error].to_s, entry: x[:entry].to_h } }
        }
        JSON.generate(h)
      end
    end
  end
end
