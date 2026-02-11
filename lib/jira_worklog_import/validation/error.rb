# frozen_string_literal: true

module JiraWorklogImport
  module Validation
    class Error < StandardError
      attr_reader :entry, :validator_name

      def initialize(message, entry: nil, validator_name: nil)
        super(message)
        @entry = entry
        @validator_name = validator_name
      end
    end
  end
end
