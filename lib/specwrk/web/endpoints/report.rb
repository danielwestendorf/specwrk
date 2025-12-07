# frozen_string_literal: true

require "specwrk/web/endpoints/base"

module Specwrk
  class Web
    module Endpoints
      class Report < Base
        def with_response
          completed_dump = completed.dump
          completed_dump[:meta][:unexecuted] = pending.length + processing.length
          completed_dump[:flakes] = failure_counts.to_h.reject { |id, _count| completed_dump.dig(:examples, id, :status) == "failed" }

          [200, {"content-type" => "application/json"}, [JSON.generate(completed_dump)]]
        end
      end
    end
  end
end
