# frozen_string_literal: true

require "date"

module JiraWorklogImport
  class Pipeline
    def initialize(
      csv_reader:,
      mapper:,
      validation_chain: nil,
      deduplication_hasher: nil,
      deduplication_store: nil,
      jira_worklogs:,
      mapper_time_formatter: nil,
      report: nil,
      dry_run: false,
      rate_limiter: nil,
      retry_policy: nil,
      rollback_store: nil,
      timezone: nil,
      on_import: nil,
      start_date: nil,
      end_date: nil
    )
      @csv_reader = csv_reader
      @mapper = mapper
      @validation_chain = validation_chain
      @deduplication_hasher = deduplication_hasher
      @deduplication_store = deduplication_store
      @jira_worklogs = jira_worklogs
      @mapper_time_formatter = mapper_time_formatter || mapper
      @report = report
      @dry_run = dry_run
      @rate_limiter = rate_limiter
      @retry_policy = retry_policy
      @rollback_store = rollback_store
      @timezone = timezone
      @on_import = on_import
      @start_date = start_date
      @end_date = end_date
    end

    def run(csv_source)
      table = @csv_reader.read(csv_source)
      entries = @mapper.map_all(table)
      entries = filter_entries_by_date_range(entries)

      to_process = entries.map { |entry| [entry, validate(entry)] }
      valid_issue_keys = to_process.select { |_, result| result == :ok }.map { |entry, _| entry.issue_key }.uniq
      existing_import_ids_by_issue = fetch_existing_import_ids_by_issue(valid_issue_keys)

      results = []
      rollback_entries = []

      to_process.each do |entry, validation_result|
        if validation_result != :ok
          @report&.add_failed(entry, validation_result)
          next
        end
        if skip_dedup?(entry, existing_import_ids_by_issue)
          @report&.add_skipped(entry, "duplicate")
          next
        end

        if @dry_run
          payload = build_payload(entry)
          @report&.add_imported(entry, nil)
          results << { entry: entry, payload: payload, dry_run: true }
          next
        end

        @rate_limiter&.throttle
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        worklog_id = send_with_retry(entry)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        if worklog_id
          @report&.add_imported(entry, worklog_id)
          rollback_entries << {
            issue_key: entry.issue_key,
            worklog_id: worklog_id,
            hash: nil
          }
          @on_import&.call(entry, worklog_id, duration)
          results << { entry: entry, worklog_id: worklog_id }
        else
          @report&.add_failed(entry, "No worklog ID returned")
        end
      rescue Jira::Error => e
        @report&.add_failed(entry, e)
      end

      @rollback_store&.save_run(rollback_entries) if @rollback_store && !@dry_run && rollback_entries.any?
      results
    end

    private

    def fetch_existing_import_ids_by_issue(issue_keys)
      return {} unless @deduplication_hasher && @jira_worklogs.respond_to?(:existing_import_ids)

      issue_keys.each_with_object({}) do |issue_key, out|
        @rate_limiter&.throttle
        out[issue_key] = @jira_worklogs.existing_import_ids(issue_key)
      end
    end

    def skip_dedup?(entry, existing_import_ids_by_issue)
      return false unless @deduplication_hasher

      existing = existing_import_ids_by_issue[entry.issue_key]
      return false unless existing

      id = @deduplication_hasher.import_id(entry)
      existing.include?(id)
    end

    def build_payload(entry)
      payload = entry.to_jira_payload(@mapper_time_formatter.time_payload_for(entry.time_spent), timezone: @timezone)
      return payload unless @deduplication_hasher

      tag = "#{Deduplication::TAG_PREFIX}#{@deduplication_hasher.import_id(entry)}]"
      comment = payload[:comment].to_s
      comment = comment.strip.empty? ? tag : "#{comment}\n\n#{tag}"
      payload.merge(comment: comment)
    end

    def filter_entries_by_date_range(entries)
      return entries if !@start_date && !@end_date

      entries.select do |entry|
        d = entry_date(entry)
        next false unless d
        next false if @start_date && d < @start_date
        next false if @end_date && d > @end_date
        true
      end
    end

    def entry_date(entry)
      return nil unless entry.date

      entry.date.respond_to?(:to_date) ? entry.date.to_date : Date.parse(entry.date.to_s)
    rescue ArgumentError
      nil
    end

    def validate(entry)
      return :ok unless @validation_chain

      @validation_chain.validate(entry)
      :ok
    rescue Validation::Error => e
      e.message
    end

    def send_with_retry(entry)
      payload = build_payload(entry)
      if @retry_policy
        @retry_policy.run { @jira_worklogs.add(entry.issue_key, payload) }
      else
        @jira_worklogs.add(entry.issue_key, payload)
      end
    end
  end
end
