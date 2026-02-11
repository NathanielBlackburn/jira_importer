# frozen_string_literal: true

module JiraWorklogImport
  module Validation
    class Chain
      def initialize(validators)
        @validators = validators
      end

      def validate(entry)
        errors = []
        @validators.each do |validator|
          validator.validate(entry)
        end
        true
      rescue Validation::Error => e
        raise e
      end

      def validate_all(entries)
        entries.map do |entry|
          [entry, validate_one(entry)]
        end
      end

      def validate_one(entry)
        validate(entry)
        [:ok, entry]
      rescue Validation::Error => e
        [:error, e]
      end
    end
  end
end
