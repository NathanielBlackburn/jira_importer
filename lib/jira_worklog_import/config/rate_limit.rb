# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class RateLimit
      attr_reader :requests_per_second, :max_retries, :backoff_base

      def initialize(requests_per_second: 10, max_retries: 3, backoff_base: 2)
        @requests_per_second = requests_per_second
        @max_retries = max_retries
        @backoff_base = backoff_base
      end

      def self.from_hash(hash)
        new(
          requests_per_second: hash["requests_per_second"] || hash[:requests_per_second] || 10,
          max_retries: hash["max_retries"] || hash[:max_retries] || 3,
          backoff_base: hash["backoff_base"] || hash[:backoff_base] || 2
        )
      end
    end
  end
end
