# frozen_string_literal: true

require "specwrk/web/endpoints/base"

module Specwrk
  class Web
    module Endpoints
      class Report < Base
        def with_response
          cached_report = metadata[:report_json]
          return report_response(cached_report) if cached_report

          with_lock do
            cached_report = metadata[:report_json]
            if cached_report
              report_response(cached_report)
            else
              report_json = JSON.generate(report_data)
              metadata[:report_json] = report_json
              report_response(report_json)
            end
          end
        end

        private

        def report_data
          completed_dump = completed.dump
          completed_dump[:meta][:unexecuted] = pending.length + processing.length
          completed_dump[:flakes] = failure_counts.to_h.reject { |id, _count| completed_dump.dig(:examples, id, :status) == "failed" }

          completed_dump
        end

        def report_response(report_json)
          [200, {"content-type" => "application/json"}, [report_json]]
        end
      end
    end
  end
end
