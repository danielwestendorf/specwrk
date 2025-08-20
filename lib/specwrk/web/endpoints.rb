# frozen_string_literal: true

require "json"

require "specwrk/store"

module Specwrk
  class Web
    module Endpoints
      class Base
        attr_reader :started_at

        def initialize(request)
          @request = request
        end

        def response
          before_lock

          return with_response unless run_id # No run_id, no datastore usage in the endpoint

          payload # parse the payload before any locking

          worker[:first_seen_at] ||= Time.now.iso8601
          worker[:last_seen_at] = Time.now.iso8601

          final_response = with_lock do
            started_at = metadata[:started_at] ||= Time.now.iso8601
            @started_at = Time.parse(started_at)

            with_response
          end

          after_lock

          final_response[1]["x-specwrk-status"] = worker_status.to_s

          final_response
        end

        def with_response
          not_found
        end

        private

        attr_reader :request

        def before_lock
        end

        def after_lock
        end

        def not_found
          if request.head?
            [404, {}, []]
          else
            [404, {"content-type" => "text/plain"}, ["This is not the path you're looking for, 'ol chap..."]]
          end
        end

        def ok
          if request.head?
            [200, {}, []]
          else
            [200, {"content-type" => "text/plain"}, ["OK, 'ol chap"]]
          end
        end

        def payload
          return unless request.content_type&.start_with?("application/json")
          return unless request.post? || request.put? || request.delete?
          return if body.empty?

          @payload ||= JSON.parse(body, symbolize_names: true)
        end

        def body
          @body ||= request.body.read
        end

        def pending
          @pending ||= PendingStore.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "pending"))
        end

        def processing
          @processing ||= ProcessingStore.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "processing"))
        end

        def completed
          @completed ||= CompletedStore.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "completed"))
        end

        def failure_counts
          @failure_counts ||= Store.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "failure_counts"))
        end

        def metadata
          @metadata ||= Store.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "metadata"))
        end

        def run_times
          @run_times ||= Store.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "file://#{File.join(Dir.tmpdir, "specwrk")}"), "run_times")
        end

        def worker
          @worker ||= Store.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "workers", request.get_header("HTTP_X_SPECWRK_ID").to_s))
        end

        def worker_status
          return 0 if worker[:failed].nil? && completed.any? # worker starts after run has completed

          worker[:failed] || 1
        end

        def run_id
          request.get_header("HTTP_X_SPECWRK_RUN")
        end

        def with_lock
          Store.with_lock(URI(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///")), "server") { yield }
        end
      end

      # Base default response is 404
      NotFound = Class.new(Base)

      class Health < Base
        def with_response
          ok
        end
      end

      class Heartbeat < Base
        def with_response
          ok
        end
      end

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

      class Popable < Base
        private

        def with_pop_response
          if examples.any?
            [200, {"content-type" => "application/json"}, [JSON.generate(examples)]]
          elsif pending.empty? && processing.empty? && completed.empty?
            [204, {"content-type" => "text/plain"}, ["Waiting for sample to be seeded."]]
          elsif completed.any? && processing.empty?
            [410, {"content-type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]
          elsif processing.any? && processing.expired.keys.any?
            pending.merge!(processing.expired)
            processing.delete(*processing.expired.keys)
            @examples = nil

            [200, {"content-type" => "application/json"}, [JSON.generate(examples)]]
          else
            not_found
          end
        end

        def examples
          @examples ||= begin
            examples = pending.shift_bucket
            bucket_run_time_total = examples.map { |example| example.fetch(:expected_run_time, 10.0) }.compact.sum * 2
            maximum_completion_threshold = (pending.run_time_bucket_maximum || 30.0) * 2
            completion_threshold = Time.now + [bucket_run_time_total, maximum_completion_threshold, 20.0].max

            processing_data = examples.map do |example|
              [
                example[:id], example.merge(completion_threshold: completion_threshold.to_f)
              ]
            end

            processing.merge!(processing_data.to_h)

            examples
          end
        end
      end

      class Pop < Popable
        def with_response
          with_pop_response
        end
      end

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

      class Report < Base
        def with_response
          completed_dump = completed.dump
          completed_dump[:meta][:unexecuted] = pending.length + processing.length
          completed_dump[:flakes] = failure_counts.to_h.reject { |id, _count| completed_dump.dig(:examples, id, :status) == "failed" }

          [200, {"content-type" => "application/json"}, [JSON.generate(completed_dump)]]
        end
      end

      class Shutdown < Base
        def with_response
          interupt! if ENV["SPECWRK_SRV_SINGLE_RUN"]

          [200, {"content-type" => "text/plain"}, ["✌️"]]
        end

        def interupt!
          Thread.new do
            # give the socket a moment to flush the response
            sleep 0.2
            Process.kill("INT", Process.pid)
          end
        end
      end
    end
  end
end
