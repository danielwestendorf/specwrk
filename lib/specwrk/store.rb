# frozen_string_literal: true

require "time"
require "json"

require "specwrk/store/file_adapter"

module Specwrk
  class Store
    MUTEXES = {}
    MUTEXES_MUTEX = Mutex.new # 🐢🐢🐢🐢

    class << self
      def mutex_for(path)
        MUTEXES_MUTEX.synchronize do
          MUTEXES[path] ||= Mutex.new
        end
      end
    end

    def initialize(path, thread_safe_reads: true)
      @path = path
      @thread_safe_reads = thread_safe_reads
    end

    def [](key)
      sync(thread_safe: thread_safe_reads) { adapter[key.to_s] }
    end

    def multi_read(*keys)
      sync(thread_safe: thread_safe_reads) { adapter.multi_read(*keys) }
    end

    def []=(key, value)
      sync do
        adapter[key.to_s] = value
      end
    end

    def keys
      all_keys = sync(thread_safe: thread_safe_reads) do
        adapter.keys
      end

      all_keys.reject { |k| k.start_with? "____" }
    end

    def length
      keys.length
    end

    def any?
      !empty?
    end

    def empty?
      sync(thread_safe: thread_safe_reads) do
        adapter.empty?
      end
    end

    def delete(*keys)
      sync { adapter.delete(*keys) }
    end

    def merge!(h2)
      h2.transform_keys!(&:to_s)
      sync { adapter.merge!(h2) }
    end

    def clear
      sync { adapter.clear }
    end

    def to_h
      sync(thread_safe: thread_safe_reads) do
        adapter.multi_read(*keys).transform_keys!(&:to_sym)
      end
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

    attr_reader :thread_safe_reads

    def sync(thread_safe: true)
      if !thread_safe || mutex.owned?
        yield
      else
        mutex.synchronize { yield }
      end
    end

    def adapter
      @adapter ||= FileAdapter.new(@path)
    end

    def mutex
      @mutex ||= self.class.mutex_for(@path)
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
      sync do
        return bucket_by_file unless run_time_bucket_maximum&.positive?

        case ENV["SPECWRK_SRV_GROUP_BY"]
        when "file"
          bucket_by_file
        else
          bucket_by_timings
        end
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
        all_keys.each_slice(25).each do |key_group|
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
        keys.each_slice(25).each do |key_group|
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
