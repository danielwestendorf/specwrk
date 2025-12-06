# frozen_string_literal: true

require "time"
require "specwrk/store/base"

module Specwrk
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
