# frozen_string_literal: true

require "specwrk/web/endpoints/base"

module Specwrk
  class Web
    module Endpoints
      class Shutdown < Base
        def with_response
          interupt! if ENV["SPECWRK_SRV_SINGLE_RUN"]

          [200, {"content-type" => "text/plain"}, ["✌️"]]
        end

        private

        def skip_lock
          true
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
