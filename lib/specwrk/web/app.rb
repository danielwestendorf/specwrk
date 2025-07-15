# frozen_string_literal: true

require "pathname"
require "fileutils"

require "webrick"
require "rack"

# rack v3 or v2
begin
  require "rackup/handler/webrick"
rescue LoadError
  require "rack/handler/webrick"
end

require "specwrk/web"
require "specwrk/web/logger"
require "specwrk/web/auth"
require "specwrk/web/endpoints"

module Specwrk
  class Web
    class App
      REAP_INTERVAL = 330 # HTTP connection timeout + some buffer

      class << self
        def run!
          Process.setproctitle "specwrk-server"

          setup!

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

        def setup!
          if ENV["SPECWRK_OUT"]

            FileUtils.mkdir_p(ENV["SPECWRK_OUT"])
            ENV["SPECWRK_SRV_LOG"] ||= Pathname.new(File.join(ENV["SPECWRK_OUT"], "server.log")).to_s unless ENV["SPECWRK_SRV_VERBOSE"]
            ENV["SPECWRK_SRV_OUTPUT"] ||= Pathname.new(File.join(ENV["SPECWRK_OUT"], "report.json")).expand_path(Dir.pwd).to_s
          end

          if ENV["SPECWRK_SRV_LOG"]
            $stdout.reopen(ENV["SPECWRK_SRV_LOG"], "w")
          end
        end

        def rackup
          Rack::Builder.new do
            if ENV["SPECWRK_SRV_VERBOSE"]
              use Rack::Runtime
              use Specwrk::Web::Logger, $stdout, %w[/health]
            end

            use Specwrk::Web::Auth, %w[/health] # global auth check
            run Specwrk::Web::App.new           # your router
          end
        end
      end

      def initialize
        @reaper_thread = Thread.new { reaper } unless ENV["SPECWRK_SRV_SINGLE_RUN"]
      end

      def call(env)
        env[:request] ||= Rack::Request.new(env)

        route(method: env[:request].request_method, path: env[:request].path_info)
          .new(env[:request])
          .response
      end

      def route(method:, path:)
        case [method, path]
        when ["GET", "/health"]
          Endpoints::Health
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

      def reaper
        until Specwrk.force_quit
          sleep REAP_INTERVAL

          reap
        end
      end

      def reap
        Web::WORKERS.each do |run, workers|
          most_recent_last_seen_at = workers.map { |id, worker| worker[:last_seen_at] }.max
          next unless most_recent_last_seen_at

          # Don't consider runs which aren't at least REAP_INTERVAL sec stale
          if most_recent_last_seen_at < Time.now - REAP_INTERVAL
            Web.clear_run_queues(run)
          end
        end
      end
    end
  end
end
