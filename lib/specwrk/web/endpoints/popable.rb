# frozen_string_literal: true

require "specwrk/web/endpoints/base"

module Specwrk
  class Web
    module Endpoints
      class Popable < Base
        private

        def with_pop_response
          if examples.any?
            [200, {"content-type" => "application/json"}, [JSON.generate(examples)]]
          elsif pending.empty? && processing.empty? && completed.empty?
            [204, {"content-type" => "text/plain"}, ["Waiting for sample to be seeded."]]
          elsif completed.any? && processing.empty?
            [410, {"content-type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]
          elsif expired_examples.length.positive?
            pending.merge!(expired_examples.each { |_id, example| example[:worker_id] = worker_id })
            processing.delete(*expired_examples.keys)
            @examples = nil

            [200, {"content-type" => "application/json"}, [JSON.generate(examples)]]
          else
            not_found
          end
        end

        def examples
          @examples ||= begin
            examples = pending.shift_bucket

            processing_data = examples.map do |example|
              [
                example[:id], example.merge(worker_id: worker_id)
              ]
            end

            processing.merge!(processing_data.to_h)

            examples
          end
        end

        def expired_examples
          return unless processing.any?

          @expired_examples ||= processing.to_h.select { |_id, example| expired?(example) }
        end

        # Has the worker missed two heartbeat check-ins?
        def expired?(example)
          return false unless example[:worker_id]

          workers_last_heartbeats[example[:worker_id]] < Time.now - 20
        end

        def workers_last_heartbeats
          @workers_last_heartbeats ||= Hash.new do |h, k|
            h[k] = worker_store_for(k).last_seen_at || Time.at(0)
          end
        end
      end
    end
  end
end
