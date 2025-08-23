# frozen_string_literal: true

require "specwrk/web/endpoints/popable"

module Specwrk
  class Web
    module Endpoints
      class Pop < Popable
        def with_response
          with_pop_response
        end
      end
    end
  end
end
