# frozen_string_literal: true

require "cgi"
require "json"
require "ostruct"
require "thor"

module JiraWorklogImport
  module Cli
    class Main < Thor
      class_option :"dry-run", type: :boolean, default: false, desc: "Validate and print what would be sent; do not call Jira API"
      class_option :verbose, type: :boolean, default: false, desc: "Verbose output"
      class_option :config, type: :string, desc: "Path to config.yml"
      class_option :"report-json", type: :string, desc: "Write JSON report to file"

      desc "import [SOURCE]", "Import worklogs from CSV (file path or Google Sheets URL). SOURCE optional if csv.source_url is set in config."
      option :"start-date", type: :string, desc: "Import only logs with date >= this (YYYY-mm-dd, midnight)"
      option :"end-date", type: :string, desc: "Import only logs with date <= this (YYYY-mm-dd, midnight)"
      def import(source = nil)
        config_path = options["config"] || ENV["CONFIG_PATH"]
        config = Config::Loader.new(config_path: config_path).load

        source = (source.to_s.strip.empty? ? nil : source.to_s) || config.csv.source_url
        raise "No CSV source. Provide a file path or URL, or set csv.source_url in config.yml." if source.to_s.strip.empty?

        start_date = parse_import_date(options["start-date"], "start-date")
        end_date = parse_import_date(options["end-date"], "end-date")
        raise "start-date must be <= end-date" if start_date && end_date && start_date > end_date

        report = build_report
        pipeline = build_pipeline(config, report, start_date: start_date, end_date: end_date)

        say "Reading CSV from #{source}...", :green if options[:verbose]
        results = run_with_activity(options, import: true) { pipeline.run(source) }

        print_report(report, results, base_url: config.jira.base_url)
        if options["report-json"]
          File.write(options["report-json"], report.to_json)
          say "Report written to #{options['report-json']}", :green if options[:verbose]
        end
        exit 1 if report.summary[:failed].positive?
      end

      desc "diagnose", "Print where .env is loaded from and whether Jira env vars are set (for debugging)"
      def diagnose
        # Same project root logic as Config::Loader (bin is at project/bin, this file at project/lib/.../cli)
        project_root = if defined?(Bundler) && Bundler.respond_to?(:root)
          Bundler.root.to_s
        else
          File.expand_path(File.join(__dir__, "../../.."))
        end
        env_path = File.expand_path(".env", project_root)

        say "--- .env diagnosis ---", :cyan
        say "  Current working directory:  #{Dir.pwd}"
        say "  Bundler.root:              #{defined?(Bundler) && Bundler.respond_to?(:root) ? Bundler.root : 'N/A'}"
        say "  Resolved .env path:         #{env_path}"
        say "  .env file exists?           #{File.exist?(env_path)}"
        if File.exist?(env_path)
          say "  .env file size:             #{File.size(env_path)} bytes", :green
        else
          say "  (Create .env in project root or run this command from project root.)", :yellow
        end

        say "\n--- ENV before Dotenv.load ---", :cyan
        %w[JIRA_BASE_URL JIRA_EMAIL JIRA_PASSWORD CONFIG_PATH].each do |key|
          val = ENV[key]
          say "  #{key}: #{val.nil? ? '(not set)' : (key.include?('PASSWORD') ? '[REDACTED]' : val)}"
        end

        if File.exist?(env_path)
          say "\n--- Loading .env now ---", :cyan
          require "dotenv"
          Dotenv.load(env_path)
          say "  Dotenv.load(#{env_path}) called.", :green
          say "\n--- ENV after Dotenv.load ---", :cyan
          %w[JIRA_BASE_URL JIRA_EMAIL JIRA_PASSWORD CONFIG_PATH].each do |key|
            val = ENV[key]
            say "  #{key}: #{val.nil? ? '(not set)' : (key.include?('PASSWORD') ? '[REDACTED]' : val)}"
          end
        end

        say ""
      end

      desc "rollback", "Roll back the last import (deletes worklogs created in the last run)"
      option :"last-run", type: :boolean, default: true, desc: "Roll back last run (default)"
      def rollback
        require_relative "../rollback/store"
        require_relative "../rollback/executor"

        config_path = options["config"] || ENV["CONFIG_PATH"]
        config = Config::Loader.new(config_path: config_path).load

        client = build_jira_client(config)
        store = Rollback::Store.new
        on_rollback = options[:verbose] ? ->(issue_key, worklog_id, duration) { say "  #{issue_key} #{worklog_id} rolled back in #{duration.round(2)}s", :green } : nil
        executor = Rollback::Executor.new(client, store, on_rollback: on_rollback)

        result = run_with_activity(options, import: false) { executor.rollback_last_run }
        say "Deleted #{result[:deleted]} worklog(s).", :green
        result[:errors].each { |e| say "  Error: #{e[:issue_key]} #{e[:worklog_id]}: #{e[:error]}", :red }
      end

      desc "purge", "Clear rollback data (last-run file); deduplication is stored in Jira worklog tags"
      def purge
        require_relative "../rollback/store"

        rollback_store = Rollback::Store.new
        rollback_store.save_run([])
        say "Cleared rollback data (#{Rollback::Store::DEFAULT_PATH}).", :green
      end

      default_task :help

      private

      SPINNER_CHARS = %w[| / - \\].freeze

      def run_with_activity(options, import:)
        show_spinner = !options[:verbose] && $stdout.tty?
        show_spinner = show_spinner && !options["dry-run"] if import
        return yield unless show_spinner

        stop_flag = [false]
        i = 0
        thread = Thread.new do
          while !stop_flag[0]
            print "\r#{SPINNER_CHARS[i % SPINNER_CHARS.size]} "
            $stdout.flush
            i += 1
            sleep 0.06
          end
        end
        result = yield
      ensure
        if show_spinner && thread
          stop_flag[0] = true
          thread.join
          print "\r  \r"
          $stdout.flush
        end
        result
      end

      def build_report
        require_relative "../reporting/report"
        Reporting::Report.new
      end

      def build_pipeline(config, report, start_date: nil, end_date: nil)
        csv_reader = Csv::Reader.new(config.csv)
        mapper = Mapping::WorklogMapper.new(config.mapping, config.time)

        validation_chain = nil
        if config.validation.enabled
          require_relative "../validation/chain"
          require_relative "../validation/issue_key_validator"
          require_relative "../validation/time_spent_validator"
          require_relative "../validation/date_validator"
          validation_chain = Validation::Chain.new([
            Validation::IssueKeyValidator.new(pattern: config.validation.issue_key_pattern),
            Validation::TimeSpentValidator.new,
            Validation::DateValidator.new(allow_future: config.validation.allow_future_dates)
          ])
        end

        deduplication_hasher = nil
        if config.deduplication.enabled && defined?(JiraWorklogImport::Deduplication::Hasher)
          require_relative "../deduplication/hasher"
          deduplication_hasher = Deduplication::Hasher.new
        end

        # Real client needed for both dedup (GET worklogs) and import (POST); dry-run only skips POST
        jira_worklogs = Jira::Worklogs.new(build_jira_client(config))
        rate_limiter = nil
        retry_policy = nil
        rollback_store = nil

        unless options["dry-run"]
          if config.rate_limit && defined?(JiraWorklogImport::Http::RateLimiter)
            require_relative "../http/rate_limiter"
            require_relative "../http/retry_policy"
            rate_limiter = Http::RateLimiter.new(requests_per_second: config.rate_limit.requests_per_second)
            retry_policy = Http::RetryPolicy.new(
              max_retries: config.rate_limit.max_retries,
              backoff_base: config.rate_limit.backoff_base
            )
          end
          if defined?(JiraWorklogImport::Rollback::Store)
            require_relative "../rollback/store"
            rollback_store = Rollback::Store.new
          end
        end

        on_import = nil
        if options[:verbose] && !options["dry-run"]
          on_import = ->(entry, _worklog_id, duration) { say "  #{entry.issue_key} imported in #{duration.round(2)}s", :green }
        end

        Pipeline.new(
          csv_reader: csv_reader,
          mapper: mapper,
          validation_chain: validation_chain,
          deduplication_hasher: deduplication_hasher,
          deduplication_store: nil,
          jira_worklogs: jira_worklogs,
          mapper_time_formatter: mapper,
          report: report,
          dry_run: options["dry-run"],
          rate_limiter: rate_limiter,
          retry_policy: retry_policy,
          rollback_store: rollback_store,
          timezone: config.time.timezone,
          on_import: on_import,
          start_date: start_date,
          end_date: end_date
        )
      end

      def parse_import_date(value, name)
        return nil if value.to_s.strip.empty?

        Date.strptime(value.to_s.strip, "%Y-%m-%d")
      rescue ArgumentError
        raise "Invalid #{name}: use YYYY-mm-dd (e.g. 2025-01-15)"
      end

      def build_jira_client(config)
        Jira::Client.new(
          base_url: config.jira.base_url,
          email: ENV["JIRA_EMAIL"] || "",
          password: ENV["JIRA_PASSWORD"] || ""
        )
      end

      def print_report(report, results, base_url: nil)
        summary = report.summary
        say "--- Summary ---", :green
        say "Imported: #{summary[:imported]}", :green
        say "Skipped:  #{summary[:skipped]}", :yellow if summary[:skipped].positive?
        say "Failed:   #{summary[:failed]}", :red if summary[:failed].positive?

        if options["dry-run"] && results.any?
          if options[:verbose] && base_url
            auth_header = verbose_authorization_header
            results.each_with_index do |r, idx|
              next unless r[:payload]

              issue_key = r[:entry].issue_key
              url_base = base_url.to_s.sub(%r{/+$}, "")
              url = "#{url_base}/rest/api/2/issue/#{CGI.escape(issue_key)}/worklog"
              payload = r[:payload].transform_keys(&:to_s)
              say "\n--- Dry-run request #{idx + 1} ---", :cyan
              say "  URL:     #{url}", :cyan
              say "  Method:  POST", :cyan
              say "  #{auth_header}", :cyan
              say "  Body:", :cyan
              say JSON.pretty_generate(payload)
            end
          else
            say "\nWould send to Jira:", :cyan
            results.each do |r|
              next unless r[:payload]

              time_str = r[:payload][:timeSpentSeconds] ? "#{r[:payload][:timeSpentSeconds]}s" : r[:payload][:timeSpent].to_s
              comment_preview = r[:entry].comment.to_s[0..50]
              comment_preview += "..." if r[:entry].comment.to_s.length > 50
              say "  #{r[:entry].issue_key}: #{time_str} - #{comment_preview}"
            end
          end
        end

        if options[:verbose] && report.respond_to?(:failed) && report.instance_variable_get(:@failed).any?
          say "\nFailed entries:", :red
          report.instance_variable_get(:@failed).each do |h|
            say "  #{h[:entry].to_h}: #{h[:error]}"
          end
        end
      end

      def verbose_authorization_header
        email = ENV["JIRA_EMAIL"].to_s
        password = ENV["JIRA_PASSWORD"].to_s
        credentials = ["#{email}:#{password}"].pack("m0")
        "Authorization: Basic #{credentials}"
      end
    end
  end
end
