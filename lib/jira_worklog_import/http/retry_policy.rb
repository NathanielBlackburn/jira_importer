# frozen_string_literal: true

module JiraWorklogImport
  module Http
    class RetryPolicy
      def initialize(max_retries: 3, backoff_base: 2)
        @max_retries = max_retries
        @backoff_base = backoff_base
      end

      def run
        attempt = 0
        begin
          yield
        rescue Faraday::TimeoutError, Faraday::ConnectionFailed, JiraWorklogImport::Jira::RetryableError => e
          attempt += 1
          raise e if attempt > @max_retries

          sleep(delay_for(attempt))
          retry
        end
      end

      private

      def delay_for(attempt)
        (@backoff_base ** attempt) + rand
      end
    end
  end
end
