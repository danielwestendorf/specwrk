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
          [404, {"Content-Type" => "text/plain"}, ["This is not the path you're looking for, 'ol chap..."]]
        end

        def ok
          [200, {"Content-Type" => "text/plain"}, ["OK, 'ol chap"]]
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
          @pending ||= PendingStore.new(File.join(datastore_path, "pending"))
        end

        def processing
          @processing ||= Store.new(File.join(datastore_path, "processing"))
        end

        def completed
          @completed ||= CompletedStore.new(File.join(datastore_path, "completed"))
        end

        def metadata
          @metadata ||= Store.new(File.join(datastore_path, "metadata"), thread_safe_reads: false)
        end

        def run_times
          @run_times ||= Store.new(File.join(ENV["SPECWRK_OUT"], "run_times"), thread_safe_reads: false)
        end

        def worker
          @worker ||= Store.new(File.join(datastore_path, "workers", request.get_header("HTTP_X_SPECWRK_ID").to_s))
        end

        def run_id
          request.get_header("HTTP_X_SPECWRK_RUN")
        end

        def run_report_file_path
          @run_report_file_path ||= File.join(datastore_path, "#{started_at.strftime("%Y%m%dT%H%M%S")}-report.json").to_s
        end

        def datastore_path
          @datastore_path ||= File.join(ENV["SPECWRK_OUT"], run_id).to_s.tap do |path|
            FileUtils.mkdir_p(path) unless File.directory?(path)
          end
        end

        def with_lock
          Thread.pass until lock_file.flock(File::LOCK_EX)
          yield
        ensure
          lock_file.flock(File::LOCK_UN)
        end

        def lock_file
          @lock_file ||= File.open(File.join(datastore_path, "lock"), "a")
        end
      end

      # Base default response is 404
      NotFound = Class.new(Base)

      class Health < Base
        def with_response
          [200, {}, []]
        end
      end

      class Heartbeat < Base
        def with_response
          ok
        end
      end

      class Seed < Base
        def before_lock
          examples_with_run_times if persist_seeds?
        end

        def with_response
          if persist_seeds?
            new_run_time_bucket_maximums = [pending.run_time_bucket_maximum, @seeds_run_time_bucket_maximum.to_f].compact
            pending.run_time_bucket_maximum = new_run_time_bucket_maximums.sum.to_f / new_run_time_bucket_maximums.length.to_f

            pending.merge!(examples_with_run_times)
          end

          processing.clear
          completed.clear

          ok
        end

        def examples_with_run_times
          @examples_with_run_times ||= begin
            unsorted_examples_with_run_times = []
            all_ids = payload.map { |example| example[:id] }
            all_run_times = run_times.multi_read(*all_ids)

            payload.each do |example|
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

        def persist_seeds?
          ENV["SPECWRK_SRV_SINGLE_SEED_PER_RUN"].nil? || pending.empty?
        end

        def sort_by
          if ENV["SPECWRK_SRV_GROUP_BY"] == "file" || run_times.empty?
            :file
          else
            :timings
          end
        end
      end

      class Complete < Base
        def with_response
          completed.merge!(completed_examples)
          processing.delete(*completed_examples.keys)

          ok
        end

        private

        def completed_examples
          @completed_data ||= payload.map { |example| [example[:id], example] if processing[example[:id]] }.compact.to_h
        end

        # We don't care about exact values here, just approximate run times are fine
        # So if we overwrite run times from another process it is nbd
        def after_lock
          run_time_data = payload.map { |example| [example[:id], example[:run_time]] }.to_h
          run_times.merge! run_time_data
        end
      end

      class Pop < Base
        def with_response
          @examples = pending.shift_bucket

          processing_data = @examples.map { |example| [example[:id], example] }.to_h
          processing.merge!(processing_data)

          if @examples.any?
            [200, {"Content-Type" => "application/json"}, [JSON.generate(@examples)]]
          elsif pending.empty? && processing.empty? && completed.empty?
            [204, {"Content-Type" => "text/plain"}, ["Waiting for sample to be seeded."]]
          elsif completed.any? && processing.empty?
            [410, {"Content-Type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]
          else
            not_found
          end
        end
      end

      class Report < Base
        def with_response
          [200, {"Content-Type" => "application/json"}, [JSON.generate(completed.dump)]]
        end
      end

      class Shutdown < Base
        def with_response
          pending.clear
          processing.clear

          interupt! if ENV["SPECWRK_SRV_SINGLE_RUN"]

          [200, {"Content-Type" => "text/plain"}, ["✌️"]]
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
