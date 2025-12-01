# frozen_string_literal: true

require "specwrk/web/endpoints/base"

module Specwrk
  class Web
    module Endpoints
      class Heartbeat < Base
        def with_response
          ok
        end

        private

        def skip_lock
          false
        end
      end
    end
  end
end
