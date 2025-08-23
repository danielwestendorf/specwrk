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
    end
  end
end
