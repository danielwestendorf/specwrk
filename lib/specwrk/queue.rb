# frozen_string_literal: true

require "time"
require "json"

module Specwrk
  Queue = Class.new(Hash)

  class PendingQueue < Queue
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

    def previous_run_times
      return unless ENV["SPECWRK_OUT"]

      @previous_run_times ||= begin
        return unless previous_run_times_file_path
        return unless File.exist? previous_run_times_file_path

        raw_data = File.open(previous_run_times_file_path, "r") do |file|
          file.flock(File::LOCK_SH)
          file.read
        end

        @previous_run_times = JSON.parse(raw_data, symbolize_names: true)
      rescue JSON::ParserError => e
        warn "#{e.inspect} in file #{previous_run_times_file_path}"
        nil
      end
    end

    def merge_with_previous_run_times!(h2)
      h2.each { |_id, example| merge_example(example) }

      # Sort by exepcted run time, slowest to fastest
      new_h = sort_by { |_, example| example[:expected_run_time] }.reverse.to_h
      clear
      merge!(new_h)
    end

    private

    # We want the most recently modified run time file
    # report files are prefixed with a timestamp, and Dir.glob should order
    # alphanumericly
    def previous_run_times_file_path
      return unless ENV["SPECWRK_OUT"]

      @previous_run_times_file_path ||= Dir.glob(File.join(ENV["SPECWRK_OUT"], "*-report-*.json")).last
    end

    # Take elements from the hash where the file_path is the same
    def bucket_by_file
      bucket = []

      key = keys.first
      return [] if key.nil?

      file_path = self[key][:file_path]
      each do |id, example|
        next unless example[:file_path] == file_path

        bucket << example
        delete id
      end

      bucket
    end

    # Take elements from the hash until the average runtime bucket has filled
    def bucket_by_timings
      bucket = []

      estimated_run_time_total = 0

      while estimated_run_time_total < run_time_bucket_threshold
        key = keys.first
        break if key.nil?

        estimated_run_time_total += dig(key, :expected_run_time)
        break if estimated_run_time_total > run_time_bucket_threshold && bucket.length.positive?

        bucket << self[key]
        delete key
      end

      bucket
    end

    def merge_example(example)
      return if key? example[:id]
      return if key? example[:file_path]

      self[example[:id]] = if previous_run_times
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
      @run_times = []
      @first_started_at = Time.new(2999, 1, 1, 0, 0, 0) # TODO: Make future proof /s
      @last_finished_at = Time.new(1900, 1, 1, 0, 0, 0)

      @output = {
        file_totals: Hash.new { |h, filename| h[filename] = 0.0 },
        meta: {failures: 0, passes: 0, pending: 0},
        examples: {}
      }

      values.each { |example| calculate(example) }

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

    def write_output_to(path, output)
      File.open(path, "w") do |file|
        file.flock(File::LOCK_EX)

        file.write JSON.pretty_generate(output)

        file.flock(File::LOCK_UN)
      end
    end
  end
end
