# frozen_string_literal: true

require "csv"
require "net/http"
require "openssl"
require "uri"

module JiraWorklogImport
  module Csv
    class Reader
      def initialize(csv_config)
        @delimiter = csv_config.delimiter
        @encoding = csv_config.encoding
        @skip_ssl_verify = csv_config.skip_ssl_verify
      end

      GOOGLE_SHEETS_ID = %r{\b(?:https?://)?(?:www\.)?docs\.google\.com/spreadsheets/d/([a-zA-Z0-9_-]+)}i

      def read(source)
        content = fetch_content(source)
        parse(content)
      end

      private

      def fetch_content(source)
        source = normalize_google_sheets_url(source.to_s.strip)
        uri = parse_uri(source)
        if uri && %w[http https].include?(uri.scheme)
          fetch_from_url(uri)
        else
          fetch_from_file(source)
        end
      end

      def normalize_google_sheets_url(source)
        return source if source.empty?

        match = source.match(GOOGLE_SHEETS_ID)
        return source unless match

        sheet_id = match[1]
        "https://docs.google.com/spreadsheets/d/#{sheet_id}/export?format=csv"
      end

      def parse_uri(str)
        URI.parse(str)
      rescue URI::InvalidURIError
        nil
      end

      REDIRECT_LIMIT = 10

      def fetch_from_url(uri, redirect_count = 0)
        raise "Too many redirects" if redirect_count > REDIRECT_LIMIT

        response = http_get(uri)
        case response
        when Net::HTTPSuccess
          response.body.force_encoding(@encoding)
        when Net::HTTPRedirection
          location = response["location"]
          raise "Redirect with no Location header" unless location

          redirect_uri = uri.merge(location)
          fetch_from_url(redirect_uri, redirect_count + 1)
        else
          raise "HTTP #{response.code}: #{response.message}"
        end
      end

      def http_get(uri)
        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = (uri.scheme == "https")
        if @skip_ssl_verify && http.use_ssl?
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request)
      end

      def fetch_from_file(path)
        path = path.to_s
        raise ArgumentError, "File not found: #{path}" unless File.exist?(path)

        File.read(path, encoding: @encoding)
      end

      def parse(content)
        ::CSV.parse(
          content,
          headers: true,
          col_sep: @delimiter,
          encoding: @encoding
        )
      end
    end
  end
end
