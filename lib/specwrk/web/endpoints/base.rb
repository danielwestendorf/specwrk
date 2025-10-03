# frozen_string_literal: true

require "json"

require "specwrk/store"

module Specwrk
  class Web
    module Endpoints
      class Base
        MUTEX = Mutex.new

        attr_reader :started_at

        def initialize(request)
          @request = request
        end

        def response
          return with_response unless run_id # No run_id, no datastore usage in the endpoint

          payload # parse the payload before any locking

          before_lock

          worker.first_seen_at ||= Time.now
          worker.last_seen_at = Time.now

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

        def skip_lock
          false
        end

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
          @worker ||= worker_store_for(worker_id)
        end

        def worker_id
          request.get_header("HTTP_X_SPECWRK_ID").to_s
        end

        def worker_status
          return 0 if worker[:failed].nil? && completed.any? # worker starts after run has completed

          worker[:failed] || 1
        end

        def worker_store_for(id)
          WorkerStore.new(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///"), File.join(run_id, "workers", id))
        end

        def run_id
          request.get_header("HTTP_X_SPECWRK_RUN")
        end

        def with_lock
          if skip_lock
            yield
          else
            with_mutex do
              Store.with_lock(URI(ENV.fetch("SPECWRK_SRV_STORE_URI", "memory:///")), run_id) { yield }
            end
          end
        end

        def with_mutex
          if Thread.current == Thread.main
            yield
          else
            MUTEX.synchronize { yield }
          end
        end
      end

      # Base default response is 404
      NotFound = Class.new(Base)
    end
  end
end
