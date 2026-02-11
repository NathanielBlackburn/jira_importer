# frozen_string_literal: true

require "json"
require "set"

module JiraWorklogImport
  module Deduplication
    class Store
      def initialize(path)
        @path = path
        @hashes = load
      end

      def include?(hash)
        @hashes.include?(hash)
      end

      def add(hash)
        @hashes.add(hash)
        save
      end

      def add_many(hashes)
        hashes.each { |h| @hashes.add(h) }
        save
      end

      def remove(hash)
        @hashes.delete(hash)
        save
      end

      def clear
        @hashes.clear
        save
      end

      def size
        @hashes.size
      end

      private

      def load
        return Set.new unless File.exist?(@path)

        data = JSON.parse(File.read(@path))
        Set.new(data["hashes"] || [])
      rescue JSON::ParserError, Errno::ENOENT
        Set.new
      end

      def save
        File.write(@path, JSON.pretty_generate({ "hashes" => @hashes.to_a }))
      end
    end
  end
end
