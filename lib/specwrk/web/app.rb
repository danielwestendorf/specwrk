# frozen_string_literal: true

require "webrick"
require "rack"

# rack v3 or v2
begin
  require "rackup/handler/webrick"
rescue LoadError
  require "rack/handler/webrick"
end

require "specwrk/web/logger"
require "specwrk/web/auth"
require "specwrk/web/endpoints"

module Specwrk
  class Web
    class App
      class << self
        def run!
          Process.setproctitle "specwrk-server"

          if ENV["SPECWRK_SRV_LOG"]
            $stdout.reopen(ENV["SPECWRK_SRV_LOG"], "w")
          end

          server_opts = {
            Port: ENV.fetch("SPECWRK_SRV_PORT", "5138").to_i,
            BindAddress: ENV.fetch("SPECWRK_SRV_BIND", "127.0.0.1"),
            Logger: WEBrick::Log.new($stdout, WEBrick::Log::FATAL),
            AccessLog: [],
            KeepAliveTimeout: 300
          }

          # rack v3 or v2
          handler_klass = defined?(Rackup::Handler) ? Rackup::Handler::WEBrick : Rack::Handler.get("webrick")

          handler_klass.run(rackup, **server_opts) do |server|
            ["INT", "TERM"].each do |sig|
              trap(sig) do
                puts "\n→ Shutting down gracefully..." unless ENV["SPECWRK_FORKED"]
                server.shutdown
              end
            end
          end
        end

        def rackup
          Rack::Builder.new do
            use Rack::Runtime
            use Specwrk::Web::Logger, $stdout
            use Specwrk::Web::Auth          # global auth check
            run Specwrk::Web::App.new       # your router
          end
        end
      end

      def call(env)
        env[:request] ||= Rack::Request.new(env)

        route(method: env[:request].request_method, path: env[:request].path_info)
          .new(env[:request])
          .response
      end

      def route(method:, path:)
        case [method, path]
        when ["GET", "/heartbeat"]
          Endpoints::Heartbeat
        when ["POST", "/pop"]
          Endpoints::Pop
        when ["POST", "/complete"]
          Endpoints::Complete
        when ["POST", "/seed"]
          Endpoints::Seed
        when ["GET", "/stats"]
          Endpoints::Stats
        when ["DELETE", "/shutdown"]
          Endpoints::Shutdown
        else
          Endpoints::NotFound
        end
      end
    end
  end
end
