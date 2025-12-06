# frozen_string_literal: true

require "specwrk/store/base"

module Specwrk
  class PendingStore < Store
    RUN_TIME_BUCKET_MAXIMUM_KEY = :____run_time_bucket_maximum
    ORDER_KEY = :____order
    MAX_RETRIES_KEY = :____max_retries

    def run_time_bucket_maximum=(val)
      @run_time_bucket_maximum = self[RUN_TIME_BUCKET_MAXIMUM_KEY] = val
    end

    def run_time_bucket_maximum
      @run_time_bucket_maximum ||= self[RUN_TIME_BUCKET_MAXIMUM_KEY]
    end

    def order=(val)
      @order = nil

      self[ORDER_KEY] = if val.nil? || val.length.zero?
        nil
      else
        val
      end
    end

    def order
      @order ||= self[ORDER_KEY] || []
    end

    def max_retries=(val)
      @max_retries = self[MAX_RETRIES_KEY] = val
    end

    def max_retries
      @max_retries ||= self[MAX_RETRIES_KEY] || 0
    end

    def keys
      return super if order.length.zero?

      order
    end

    def merge!(hash)
      super

      self.order = order + (hash.keys - order)
    end

    def clear
      @order = nil
      super
    end

    def reload
      @order = nil
      @max_retries = nil
      super
    end

    def shift_bucket
      return bucket_by_file unless run_time_bucket_maximum&.positive?

      case ENV["SPECWRK_SRV_GROUP_BY"]
      when "file"
        bucket_by_file
      else
        bucket_by_timings
      end
    end

    private

    # Take elements from the hash where the file_path is the same
    # Expects that the examples were merged in order of filename
    def bucket_by_file
      bucket = []
      consumed_keys = []

      all_keys = keys
      key = all_keys.first
      return [] if key.nil?

      file_path = self[key][:file_path]

      catch(:full) do
        all_keys.each_slice(24).each do |key_group|
          examples = multi_read(*key_group)

          examples.each do |key, example|
            throw :full unless example[:file_path] == file_path

            bucket << example
            consumed_keys << key
          end
        end
      end

      delete(*consumed_keys)
      self.order = order - consumed_keys
      bucket
    end

    # Take elements from the hash until the average runtime bucket has filled
    def bucket_by_timings
      bucket = []
      consumed_keys = []

      estimated_run_time_total = 0

      catch(:full) do
        keys.each_slice(24).each do |key_group|
          examples = multi_read(*key_group)

          examples.each do |key, example|
            estimated_run_time_total += example[:expected_run_time] || run_time_bucket_maximum
            throw :full if estimated_run_time_total > run_time_bucket_maximum && bucket.length.positive?

            bucket << example
            consumed_keys << key
          end
        end
      end

      delete(*consumed_keys)
      self.order = order - consumed_keys
      bucket
    end
  end
end
