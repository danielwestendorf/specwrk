# frozen_string_literal: true

require "securerandom"

require "specwrk/store/base"
require "specwrk/store/bucket_store"

module Specwrk
  class PendingStore < Store
    RUN_TIME_BUCKET_MAXIMUM_KEY = :____run_time_bucket_maximum
    MAX_RETRIES_KEY = :____max_retries
    BUCKET_IDS_KEY = :____bucket_ids

    def run_time_bucket_maximum=(val)
      @run_time_bucket_maximum = self[RUN_TIME_BUCKET_MAXIMUM_KEY] = val
    end

    def run_time_bucket_maximum
      @run_time_bucket_maximum ||= self[RUN_TIME_BUCKET_MAXIMUM_KEY]
    end

    def max_retries=(val)
      @max_retries = self[MAX_RETRIES_KEY] = val
    end

    def max_retries
      @max_retries ||= self[MAX_RETRIES_KEY] || 0
    end

    def bucket_ids=(val)
      @bucket_ids = nil

      self[BUCKET_IDS_KEY] = if val.nil? || val.length.zero?
        nil
      else
        val
      end
    end

    def bucket_ids
      @bucket_ids ||= self[BUCKET_IDS_KEY] || []
    end

    def merge!(hash)
      return self if hash.nil? || hash.empty?

      buckets = grouped_examples(hash.values)
      new_bucket_ids = buckets.map { |examples| write_bucket(examples) }

      self.bucket_ids = bucket_ids + new_bucket_ids
      self
    end

    def clear
      bucket_ids.each { |bucket_id| delete_bucket(bucket_id) }
      @bucket_ids = nil

      super
    end

    def reload
      @max_retries = nil
      @bucket_ids = nil
      super
    end

    def shift_bucket
      return nil if bucket_ids.empty?

      bucket_id = bucket_ids.first
      self.bucket_ids = bucket_ids.drop(1)
      bucket_id
    end

    def push_examples(examples)
      return self if examples.nil? || examples.empty?

      new_bucket_id = write_bucket(examples)
      self.bucket_ids = bucket_ids + [new_bucket_id]
      self
    end

    def bucket_store_for(bucket_id)
      BucketStore.new(uri.to_s, File.join(scope, "buckets", bucket_id))
    end

    def delete_bucket(bucket_id)
      bucket_store_for(bucket_id).clear
    end

    def keys
      bucket_ids
    end

    def length
      bucket_ids.length
    end

    private

    def write_bucket(examples)
      bucket_id = SecureRandom.uuid
      bucket_store_for(bucket_id).examples = examples
      bucket_id
    end

    def grouped_examples(examples)
      return [] if examples.empty?

      examples_to_group = examples.dup

      case grouping_strategy
      when :file
        group_by_file(examples_to_group)
      else
        group_by_timings(examples_to_group)
      end
    end

    # Take consecutive examples with the same file_path
    def group_by_file(examples)
      buckets = []

      examples.each do |example|
        current_bucket = buckets.last

        if current_bucket.nil? || current_bucket.first[:file_path] != example[:file_path]
          buckets << [example]
        else
          current_bucket << example
        end
      end

      buckets
    end

    # Take elements until the average runtime bucket has filled
    def group_by_timings(examples)
      buckets = []
      return group_by_file(examples) unless run_time_bucket_maximum&.positive?

      estimated_run_time_total = 0
      current_bucket = []

      examples.each do |example|
        estimated_run_time_total += example[:expected_run_time] || run_time_bucket_maximum

        if estimated_run_time_total > run_time_bucket_maximum && current_bucket.length.positive?
          buckets << current_bucket
          current_bucket = [example]
          estimated_run_time_total = example[:expected_run_time] || run_time_bucket_maximum
          next
        end

        current_bucket << example
      end

      buckets << current_bucket if current_bucket.any?
      buckets
    end

    def grouping_strategy
      return :file unless run_time_bucket_maximum&.positive?

      (ENV["SPECWRK_SRV_GROUP_BY"] == "file") ? :file : :timings
    end
  end
end
