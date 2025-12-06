# frozen_string_literal: true

require "specwrk/store/base"

module Specwrk
  class BucketStore < Store
    EXAMPLES_KEY = :____examples

    def examples=(val)
      @examples = nil

      self[EXAMPLES_KEY] = if val.nil? || val.length.zero?
        nil
      else
        val
      end
    end

    def examples
      @examples ||= self[EXAMPLES_KEY] || []
    end

    def clear
      @examples = nil
      super
    end

    def reload
      @examples = nil
      super
    end
  end

  # Backward compatibility until all callers are migrated
  Bucket = BucketStore
end
