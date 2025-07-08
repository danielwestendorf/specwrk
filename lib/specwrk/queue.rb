# frozen_string_literal: true

require "time"
require "json"

module Specwrk
  # Thread-safe Hash access
  class Queue
    def initialize(hash = {})
      if block_given?
        @mutex = Monitor.new # Reentrant locking is required here
        # It's possible to enter the proc from two threads, so we need to ||= in case
        # one thread has set a value prior to the yield.
        hash.default_proc = proc { |h, key| @mutex.synchronize { yield(h, key) } }
      end

      @mutex ||= Mutex.new # Monitor is up-to 20% slower than Mutex, so if no block is given, use a mutex
      @hash = hash
    end

    def synchronize(&blk)
      if @mutex.owned?
        yield(@hash)
      else
        @mutex.synchronize { yield(@hash) }
      end
    end

    def method_missing(name, *args, &block)
      if @hash.respond_to?(name)
        @mutex.synchronize { @hash.public_send(name, *args, &block) }
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      @hash.respond_to?(name, include_private) || super
    end
  end

  class PendingQueue < Queue
    attr_reader :previous_run_times

    def shift_bucket
      return bucket_by_file unless previous_run_times

      case ENV["SPECWRK_SRV_GROUP_BY"]
      when "file"
        bucket_by_file
      else
        bucket_by_timings
      end
    end

    def run_time_bucket_threshold
      return 1 unless previous_run_times

      previous_run_times.dig(:meta, :average_run_time)
    end

    # TODO: move reading the file to the getter method
    def previous_run_times_file=(path)
      return unless path
      return unless File.exist? path

      File.open(path, "r") do |file|
        file.flock(File::LOCK_EX)

        @previous_run_times = JSON.parse(file.read, symbolize_names: true)

        file.flock(File::LOCK_UN)
      end
    end

    def merge_with_previous_run_times!(h2)
      synchronize do
        h2.each { |_id, example| merge_example(example) }

        # Sort by exepcted run time, slowest to fastest
        @hash = @hash.sort_by { |_, example| example[:expected_run_time] }.reverse.to_h
      end
    end

    private

    # Take elements from the hash where the file_path is the same
    def bucket_by_file
      bucket = []

      @mutex.synchronize do
        key = @hash.keys.first
        break if key.nil?

        file_path = @hash[key][:file_path]
        @hash.each do |id, example|
          next unless example[:file_path] == file_path

          bucket << example
          @hash.delete id
        end
      end

      bucket
    end

    # Take elements from the hash until the average runtime bucket has filled
    def bucket_by_timings
      bucket = []

      @mutex.synchronize do
        estimated_run_time_total = 0

        while estimated_run_time_total < run_time_bucket_threshold
          key = @hash.keys.first
          break if key.nil?

          estimated_run_time_total += @hash.dig(key, :expected_run_time)
          break if estimated_run_time_total > run_time_bucket_threshold && bucket.length.positive?

          bucket << @hash[key]
          @hash.delete key
        end
      end

      bucket
    end

    # Ensure @mutex is held when calling this method
    def merge_example(example)
      return if @hash.key? example[:id]
      return if @hash.key? example[:file_path]

      @hash[example[:id]] = if previous_run_times
        example.merge!(
          expected_run_time: previous_run_times.dig(:examples, example[:id].to_sym, :run_time) || 99999.9 # run "unknown" files first
        )
      else
        example.merge!(
          expected_run_time: 99999.9 # run "unknown" files first
        )
      end
    end
  end

  class CompletedQueue < Queue
    def dump_and_write(path)
      write_output_to(path, dump)
    end

    def dump
      @mutex.synchronize do
        @run_times = []
        @first_started_at = Time.new(2999, 1, 1, 0, 0, 0) # TODO: Make future proof /s
        @last_finished_at = Time.new(1900, 1, 1, 0, 0, 0)

        @output = {
          file_totals: Hash.new { |h, filename| h[filename] = 0.0 },
          meta: {failures: 0, passes: 0, pending: 0},
          examples: {}
        }

        @hash.values.each { |example| calculate(example) }

        @output[:meta][:total_run_time] = @run_times.sum
        @output[:meta][:average_run_time] = @output[:meta][:total_run_time] / @run_times.length.to_f
        @output[:meta][:first_started_at] = @first_started_at.iso8601(6)
        @output[:meta][:last_finished_at] = @last_finished_at.iso8601(6)

        @output
      end
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

    def write_output_to(path, output)
      File.open(path, "w") do |file|
        file.flock(File::LOCK_EX)

        file.write JSON.pretty_generate(output)

        file.flock(File::LOCK_UN)
      end
    end
  end
end
