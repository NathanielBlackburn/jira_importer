# frozen_string_literal: true

module JiraWorklogImport
  module Config
    class Csv
      attr_reader :delimiter, :encoding, :skip_ssl_verify, :source_url

      def initialize(delimiter: ",", encoding: "UTF-8", skip_ssl_verify: nil, source_url: nil)
        @delimiter = delimiter
        @encoding = encoding
        # Only for URL fetches (e.g. Google Sheets behind VPN). Insecure; use only when necessary.
        @skip_ssl_verify = skip_ssl_verify.nil? ? self.class.env_skip_ssl_verify? : !!skip_ssl_verify
        @source_url = source_url.to_s.strip.empty? ? nil : source_url.to_s.strip
      end

      def self.from_hash(hash)
        raw = hash["skip_ssl_verify"] || hash[:skip_ssl_verify]
        url = hash["source_url"] || hash["google_sheet_url"] || hash[:source_url] || hash[:google_sheet_url]
        new(
          delimiter: hash["delimiter"] || hash[:delimiter] || ",",
          encoding: hash["encoding"] || hash[:encoding] || "UTF-8",
          skip_ssl_verify: raw.nil? ? nil : !!raw,
          source_url: url
        )
      end

      def self.env_skip_ssl_verify?
        v = ENV["CSV_SKIP_SSL_VERIFY"].to_s.strip.downcase
        %w[1 true yes].include?(v)
      end
    end
  end
end
