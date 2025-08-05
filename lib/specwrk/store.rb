# frozen_string_literal: true

require "time"

module Specwrk
  class Store
    class << self
      def with_lock(uri, key)
        adapter_klass(uri).with_lock(uri, key) { yield }
      end

      def adapter_klass(uri)
        case uri.scheme
        when "memory"
          require "specwrk/store/memory_adapter" unless defined?(MemoryAdapter)

          MemoryAdapter
        when "file"
          require "specwrk/store/file_adapter" unless defined?(FileAdapter)

          FileAdapter
        end
      end
    end

    def initialize(uri_string, scope)
      @uri = URI(uri_string)
      @scope = scope
    end

    def [](key)
      adapter[key.to_s]
    end

    def multi_read(*keys)
      adapter.multi_read(*keys)
    end

    def []=(key, value)
      adapter[key.to_s] = value
    end

    def keys
      all_keys = adapter.keys

      all_keys.reject { |k| k.start_with? "____" }
    end

    def length
      keys.length
    end

    def any?
      !empty?
    end

    def empty?
      adapter.empty?
    end

    def delete(*keys)
      adapter.delete(*keys)
    end

    def merge!(h2)
      h2.transform_keys!(&:to_s)
      adapter.merge!(h2)
    end

    def clear
      adapter.clear
    end

    def to_h
      adapter.multi_read(*keys).transform_keys!(&:to_sym)
    end

    def inspect
      reload.to_h.dup
    end

    # Bypass any cached values. Helpful when you have two instances
    # of the same store where one mutates data and the other needs to check
    # on the status of that data (i.e. endpoint tests)
    def reload
      @adapter = nil
      self
    end

    private

    attr_reader :uri, :scope

    def adapter
      @adapter ||= self.class.adapter_klass(uri).new uri, scope
    end
  end

  class PendingStore < Store
    RUN_TIME_BUCKET_MAXIMUM_KEY = :____run_time_bucket_maximum

    def run_time_bucket_maximum=(val)
      @run_time_bucket_maximum = self[RUN_TIME_BUCKET_MAXIMUM_KEY] = val
    end

    def run_time_bucket_maximum
      @run_time_bucket_maximum ||= self[RUN_TIME_BUCKET_MAXIMUM_KEY]
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
      bucket
    end
  end

  class ProcessingStore < Store
    def expired
      @expired ||= begin
        bucket = []

        keys.each_slice(24).each do |key_group|
          examples = multi_read(*key_group)
          examples.each do |id, example|
            next if example[:completion_threshold].nil?

            bucket << [id, example] if example[:completion_threshold] < Time.now.to_i
          end
        end

        bucket.to_h
      end
    end
  end

  class CompletedStore < Store
    def dump
      @run_times = []
      @first_started_at = Time.new(2999, 1, 1, 0, 0, 0) # TODO: Make future proof /s
      @last_finished_at = Time.new(1900, 1, 1, 0, 0, 0)

      @output = {
        file_totals: Hash.new { |h, filename| h[filename] = 0.0 },
        meta: {failures: 0, passes: 0, pending: 0},
        examples: {}
      }

      to_h.values.each { |example| calculate(example) }

      @output[:meta][:total_run_time] = @run_times.sum
      @output[:meta][:average_run_time] = @output[:meta][:total_run_time] / [@run_times.length, 1].max.to_f
      @output[:meta][:first_started_at] = @first_started_at.iso8601(6)
      @output[:meta][:last_finished_at] = @last_finished_at.iso8601(6)

      @output
    end

    private

    def calculate(example)
      @run_times << example[:run_time]
      @output[:file_totals][example[:file_path]] += example[:run_time]

      started_at = Time.parse(example[:started_at])
      finished_at = Time.parse(example[:finished_at])

      @first_started_at = started_at if started_at < @first_started_at
      @last_finished_at = finished_at if finished_at > @last_finished_at

      case example[:status]
      when "passed"
        @output[:meta][:passes] += 1
      when "failed"
        @output[:meta][:failures] += 1
      when "pending"
        @output[:meta][:pending] += 1
      end

      @output[:examples][example[:id]] = example
    end
  end
end
