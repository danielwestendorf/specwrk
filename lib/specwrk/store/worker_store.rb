# frozen_string_literal: true

require "time"
require "specwrk/store/base"

module Specwrk
  class WorkerStore < Store
    FIRST_SEEN_AT_KEY = :____first_seen_at_key
    LAST_SEEN_AT_KEY = :____last_seen_at_key

    def first_seen_at=(val)
      @first_seen_at = nil

      self[FIRST_SEEN_AT_KEY] = val.to_i
    end

    def first_seen_at
      @first_seen_at ||= begin
        value = self[FIRST_SEEN_AT_KEY]
        return @first_seen_at = value unless value

        @first_seen_at = Time.at(value.to_i)
      end
    end

    def last_seen_at=(val)
      @last_seen_at = nil

      self[LAST_SEEN_AT_KEY] = val.to_i
    end

    def last_seen_at
      @last_seen_at ||= begin
        value = self[LAST_SEEN_AT_KEY]
        return @last_seen_at = value unless value

        @last_seen_at = Time.at(value.to_i)
      end
    end

    def reload
      @last_seen_at = nil
      @first_seen_at = nil
      super
    end
  end
end
