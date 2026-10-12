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
            [204, {}, []]
          elsif completed.any? && processing.empty?
            [410, {"content-type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]
          elsif expired_examples.length.positive?
            expired_examples.each { |_id, example| example[:worker_id] = worker_id }

            with_lock do
              pending.push_examples(expired_examples.values)
              processing.delete(*expired_examples.keys.map(&:to_s))
            end

            @examples = nil

            [200, {"content-type" => "application/json"}, [JSON.generate(examples)]]
          else
            not_found
          end
        end

        def examples
          @examples ||= begin
            return [] if pending.empty?
            bucket_id = with_lock { pending.shift_bucket }
            return [] if bucket_id.nil?

            bucket = pending.bucket_store_for(bucket_id)
            examples = bucket.examples

            processing_data = examples.map do |example|
              [
                example[:id], example.merge(worker_id: worker_id, processing_started_at: Time.now.to_i)
              ]
            end

            processing.merge!(processing_data.to_h)
            bucket.clear

            examples
          end
        end

        def expired_examples
          return {} unless processing.any?

          @expired_examples ||= processing.to_h.select { |_id, example| expired?(example) }
        end

        # Has the worker missed its configured heartbeat timeout?
        def expired?(example)
          return false unless example[:worker_id]
          return false unless example[:processing_started_at]

          timeout = Integer(ENV.fetch("SPECWRK_WORKER_HEARTBEAT_TIMEOUT", "60"))
          raise ArgumentError, "SPECWRK_WORKER_HEARTBEAT_TIMEOUT must be greater than 0" unless timeout.positive?

          cutoff = Time.now - timeout
          return false unless example[:processing_started_at] < cutoff.to_i

          workers_last_heartbeats[example[:worker_id]] < cutoff
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
