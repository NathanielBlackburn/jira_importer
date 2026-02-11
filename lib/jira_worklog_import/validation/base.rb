# frozen_string_literal: true

module JiraWorklogImport
  module Validation
    class Base
      def validate(entry)
        raise NotImplementedError, "#{self.class}#validate(entry) must be implemented"
      end

      def valid?(entry)
        validate(entry)
        true
      rescue ValidationError
        false
      end
    end
  end
end
