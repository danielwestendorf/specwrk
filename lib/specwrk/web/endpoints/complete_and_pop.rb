# frozen_string_literal: true

require "specwrk/web/endpoints/popable"

module Specwrk
  class Web
    module Endpoints
      class CompleteAndPop < Popable
        EXAMPLE_STATUSES = %w[passed failed pending]

        def with_response
          completed.merge!(completed_examples)
          processing.delete(*(completed_examples.keys + retry_examples.keys))
          pending.merge!(retry_examples)
          failure_counts.merge!(retry_examples_new_failure_counts)

          with_pop_response
        end

        private

        def all_examples
          @all_examples ||= payload.map { |example| [example[:id], example] if processing[example[:id]] }.compact.to_h
        end

        def completed_examples
          @completed_examples ||= all_examples.map do |id, example|
            next if retry_example?(example)

            [id, example]
          end.compact.to_h
        end

        def retry_examples
          @retry_examples ||= all_examples.map do |id, example|
            next unless retry_example?(example)

            [id, example]
          end.compact.to_h
        end

        def retry_examples_new_failure_counts
          @retry_examples_new_failure_counts ||= retry_examples.map do |id, _example|
            [id, all_example_failure_counts.fetch(id, 0) + 1]
          end.to_h
        end

        def retry_example?(example)
          return false unless example[:status] == "failed"
          return false unless pending.max_retries.positive?

          example_failure_count = all_example_failure_counts.fetch(example[:id], 0)

          example_failure_count < pending.max_retries
        end

        def all_example_failure_counts
          @all_example_failure_counts ||= failure_counts.multi_read(*all_examples.keys)
        end

        def completed_examples_status_counts
          @completed_examples_status_counts ||= completed_examples.values.map { |example| example[:status] }.tally
        end

        def after_lock
          # We don't care about exact values here, just approximate run times are fine
          # So if we overwrite run times from another process it is nbd
          run_times.merge! run_time_data

          # workers are single proces, single-threaded, so safe to do this work without the lock
          existing_status_counts = worker.multi_read(*EXAMPLE_STATUSES)
          new_status_counts = EXAMPLE_STATUSES.map do |status|
            [status, existing_status_counts.fetch(status, 0) + completed_examples_status_counts.fetch(status, 0)]
          end.to_h

          worker.merge!(new_status_counts)
        end

        def run_time_data
          @run_time_data ||= payload.map { |example| [example[:id], example[:run_time]] }.to_h
        end
      end
    end
  end
end
