# frozen_string_literal: true

require "cgi"
require "json"
require "faraday"

module JiraWorklogImport
  module Jira
    class RetryableError < Error; end

    class Client
      def initialize(base_url:, email:, password:, connection: nil)
        @base_url = base_url.to_s.sub(%r{/+$}, "")
        @email = email
        @password = password
        @connection = connection || build_connection
      end

      def issue_exists?(issue_key)
        res = @connection.get("/rest/api/2/issue/#{CGI.escape(issue_key)}")
        res.status == 200
      rescue Faraday::Error
        false
      end

      def delete_worklog(issue_key, worklog_id)
        res = @connection.delete("/rest/api/2/issue/#{CGI.escape(issue_key)}/worklog/#{CGI.escape(worklog_id.to_s)}")
        raise Jira::Error, "Delete worklog failed: HTTP #{res.status}" unless res.status == 204
      end

      def create_worklog(issue_key, payload)
        res = @connection.post(
          "/rest/api/2/issue/#{CGI.escape(issue_key)}/worklog",
          payload.to_json,
          "Content-Type" => "application/json"
        )
        if res.status == 429 || (res.status >= 500 && res.status < 600)
          raise Jira::RetryableError, "HTTP #{res.status}"
        end
        unless res.status >= 200 && res.status < 300
          raise Jira::Error, "Worklog create failed: HTTP #{res.status}"
        end
        body = res.body.is_a?(String) ? JSON.parse(res.body) : res.body
        body["id"]
      rescue Faraday::Error => e
        raise Jira::RetryableError, e.message if e.is_a?(Faraday::TimeoutError) || e.is_a?(Faraday::ConnectionFailed)
        raise Jira::Error, "Worklog create failed: #{e.message}"
      end

      # Returns array of worklog hashes with "id", "comment", etc. Handles pagination if present.
      def get_worklogs(issue_key)
        path = "/rest/api/2/issue/#{CGI.escape(issue_key)}/worklog"
        all = []
        start_at = 0
        loop do
          res = @connection.get(path, { startAt: start_at, maxResults: 50 })
          raise Jira::Error, "Get worklogs failed: HTTP #{res.status}" unless res.status == 200
          body = res.body.is_a?(String) ? JSON.parse(res.body) : res.body
          worklogs = body["worklogs"] || []
          all.concat(worklogs)
          total = body["total"] || all.size
          break if all.size >= total || worklogs.empty?
          start_at = all.size
        end
        all
      rescue Faraday::Error => e
        raise Jira::RetryableError, e.message if e.is_a?(Faraday::TimeoutError) || e.is_a?(Faraday::ConnectionFailed)
        raise Jira::Error, "Get worklogs failed: #{e.message}"
      end

      private

      def build_connection
        Faraday.new(url: @base_url) do |f|
          f.request :authorization, :basic, @email, @password
          f.request :json
          f.response :json, content_type: /\bjson/
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
