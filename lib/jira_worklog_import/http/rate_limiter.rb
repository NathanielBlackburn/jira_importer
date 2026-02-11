# frozen_string_literal: true

module JiraWorklogImport
  module Http
    class RateLimiter
      def initialize(requests_per_second: 10)
        @min_interval = 1.0 / requests_per_second
        @last_request_at = nil
        @mutex = Mutex.new
      end

      def throttle
        @mutex.synchronize do
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if @last_request_at
            elapsed = now - @last_request_at
            sleep(@min_interval - elapsed) if elapsed < @min_interval
          end
          @last_request_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
