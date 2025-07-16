# frozen_string_literal: true

require "json"

module Specwrk
  class Web
    module Endpoints
      class Base
        def initialize(request)
          @request = request

          worker[:first_seen_at] ||= Time.now
          worker[:last_seen_at] = Time.now
        end

        def response
          not_found
        end

        private

        attr_reader :request

        def not_found
          [404, {"Content-Type" => "text/plain"}, ["This is not the path you're looking for, 'ol chap..."]]
        end

        def ok
          [200, {"Content-Type" => "text/plain"}, ["OK, 'ol chap"]]
        end

        def payload
          @payload ||= JSON.parse(body, symbolize_names: true)
        end

        def body
          @body ||= request.body.read
        end

        def pending_queue
          Web::PENDING_QUEUES[run_id]
        end

        def processing_queue
          Web::PROCESSING_QUEUES[request.get_header("HTTP_X_SPECWRK_RUN")]
        end

        def completed_queue
          Web::COMPLETED_QUEUES[request.get_header("HTTP_X_SPECWRK_RUN")]
        end

        def workers
          Web::WORKERS[request.get_header("HTTP_X_SPECWRK_RUN")]
        end

        def worker
          workers[request.get_header("HTTP_X_SPECWRK_ID")]
        end

        def run_id
          request.get_header("HTTP_X_SPECWRK_RUN")
        end
      end

      # Base default response is 404
      NotFound = Class.new(Base)

      class Health < Base
        def response
          ok
        end
      end

      class Heartbeat < Base
        def response
          ok
        end
      end

      class Seed < Base
        def response
          pending_queue.synchronize do |pending_queue_hash|
            unless ENV["SPECWRK_SRV_SINGLE_SEED_PER_RUN"] && pending_queue_hash.length.positive?
              examples = payload.map { |hash| [hash[:id], hash] }.to_h

              pending_queue.merge_with_previous_run_times!(examples)

              ok
            end
          end

          ok
        end
      end

      class Complete < Base
        def response
          processing_queue.synchronize do |processing_queue_hash|
            payload.each do |example|
              next unless processing_queue_hash.delete(example[:id])
              completed_queue[example[:id]] = example
            end
          end

          if pending_queue.length.zero? && processing_queue.length.zero? && completed_queue.length.positive? && ENV["SPECWRK_OUT"]
            completed_queue.dump_and_write(File.join(ENV["SPECWRK_OUT"], "report-#{run_id}.json").to_s)
          end

          ok
        end
      end

      class Pop < Base
        def response
          processing_queue.synchronize do |processing_queue_hash|
            @examples = pending_queue.shift_bucket

            @examples.each do |example|
              processing_queue_hash[example[:id]] = example
            end
          end

          if @examples.length.positive?
            [200, {"Content-Type" => "application/json"}, [JSON.generate(@examples)]]
          elsif pending_queue.length.zero? && processing_queue.length.zero? && completed_queue.length.zero?
            [204, {"Content-Type" => "text/plain"}, ["Waiting for sample to be seeded."]]
          elsif completed_queue.length.positive? && processing_queue.length.zero?
            [410, {"Content-Type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]
          else
            not_found
          end
        end
      end

      class Stats < Base
        def response
          data = {
            pending: {count: pending_queue.length},
            processing: {count: processing_queue.length},
            completed: completed_queue.dump
          }

          if data.dig(:completed, :examples).length.positive?
            [200, {"Content-Type" => "application/json"}, [JSON.generate(data)]]
          else
            not_found
          end
        end
      end

      class Shutdown < Base
        def response
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
