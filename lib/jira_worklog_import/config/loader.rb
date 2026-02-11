# frozen_string_literal: true

require "yaml"

module JiraWorklogImport
  module Config
    class Loader
      def initialize(env_path: ".env", config_path: nil)
        @env_path = resolve_path(env_path, project_root)
        @config_path = config_path || ENV["CONFIG_PATH"]
        @config_path = resolve_path(@config_path, project_root) if @config_path && !@config_path.start_with?("/")
      end

      def load
        load_dotenv if @env_path && File.exist?(@env_path)
        config_hash = load_yaml
        build_config(config_hash)
      end

      private

      def project_root
        @project_root ||= begin
          if defined?(Bundler) && Bundler.respond_to?(:root)
            Bundler.root.to_s
          else
            File.expand_path(File.join(__dir__, "../../.."))
          end
        end
      end

      def resolve_path(path, root)
        return nil if path.nil? || path.to_s.empty?
        path = path.to_s
        return path if File.absolute_path?(path)
        File.expand_path(path, root)
      end

      def load_dotenv
        require "dotenv"
        Dotenv.load(@env_path)
      end

      def load_yaml
        return {} unless @config_path && File.exist?(@config_path)

        YAML.load_file(@config_path) || {}
      rescue Psych::SyntaxError
        {}
      end

      def build_config(hash)
        Config::Root.new(
          jira: build_section(hash, "jira", Config::Jira),
          csv: build_section(hash, "csv", Config::Csv),
          mapping: build_section(hash, "mapping", Config::Mapping),
          time: build_section(hash, "time", Config::Time),
          validation: build_section(hash, "validation", Config::Validation),
          deduplication: build_section(hash, "deduplication", Config::Deduplication),
          rate_limit: build_section(hash, "rate_limit", Config::RateLimit)
        )
      end

      def build_section(hash, key, klass)
        klass.from_hash(hash[key] || {})
      end
    end
  end
end
