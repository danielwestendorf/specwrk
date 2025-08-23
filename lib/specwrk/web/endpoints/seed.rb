# frozen_string_literal: true

require "specwrk/web/endpoints/base"

module Specwrk
  class Web
    module Endpoints
      class Seed < Base
        def before_lock
          examples_with_run_times
        end

        def with_response
          pending.clear
          processing.clear
          failure_counts.clear

          pending.max_retries = payload.fetch(:max_retries, "0").to_i

          new_run_time_bucket_maximums = [pending.run_time_bucket_maximum, @seeds_run_time_bucket_maximum.to_f].compact
          pending.run_time_bucket_maximum = new_run_time_bucket_maximums.sum.to_f / new_run_time_bucket_maximums.length.to_f

          pending.merge!(examples_with_run_times)
          processing.clear
          completed.clear

          ok
        end

        def examples_with_run_times
          @examples_with_run_times ||= begin
            unsorted_examples_with_run_times = []
            all_ids = payload[:examples].map { |example| example[:id] }
            all_run_times = run_times.multi_read(*all_ids)

            payload[:examples].each do |example|
              run_time = all_run_times[example[:id]]

              unsorted_examples_with_run_times << [example[:id], example.merge(expected_run_time: run_time)]
            end

            sorted_examples_with_run_times = if sort_by == :timings
              unsorted_examples_with_run_times.sort_by do |entry|
                -(entry.last[:expected_run_time] || Float::INFINITY)
              end
            else
              unsorted_examples_with_run_times.sort_by do |entry|
                entry.last[:file_path]
              end
            end

            @seeds_run_time_bucket_maximum = run_time_bucket_maximum(all_run_times.values.compact)
            @examples_with_run_times = sorted_examples_with_run_times.to_h
          end
        end

        private

        # Average + standard deviation
        def run_time_bucket_maximum(values)
          return 0 if values.length.zero?

          mean = values.sum.to_f / values.size
          variance = values.map { |v| (v - mean)**2 }.sum / values.size
          (mean + Math.sqrt(variance)).round(2)
        end

        def sort_by
          if ENV["SPECWRK_SRV_GROUP_BY"] == "file" || run_times.empty?
            :file
          else
            :timings
          end
        end
      end
    end
  end
end
