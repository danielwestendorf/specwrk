# frozen_string_literal: true

module Specwrk
  class Web
    class Logger
      def initialize(app, out = $stdout, ignored_paths = [])
        @app = app
        @out = out
        @ignored_paths = ignored_paths
      end

      def call(env)
        return @app.call(env) if @ignored_paths.include? env["PATH_INFO"]

        start_time = Time.now
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        status, headers, body = @app.call(env)
        dur_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(4)

        remote = env["REMOTE_ADDR"] || env["REMOTE_HOST"] || "-"
        worker_parts = [env["HTTP_X_SPECWRK_RUN"], env["HTTP_X_SPECWRK_ID"]].compact
        context = " #{worker_parts.join(" ")}" unless worker_parts.empty?

        @out.puts "#{remote} [#{start_time.iso8601(6)}] #{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}#{context} → #{status} (#{dur_ms}ms)"
        [status, headers, body]
      end
    end
  end
end
