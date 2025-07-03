# frozen_string_literal: true

require "pathname"

require "dry/cli"

require "specwrk"
require "specwrk/hookable"

module Specwrk
  module CLI
    extend Dry::CLI::Registry

    module Clientable
      extend Hookable

      on_included do |base|
        base.unique_option :uri, type: :string, default: ENV.fetch("SPECWRK_SRV_URI", "https://localhost:#{ENV.fetch("SPECWRK_SRV_PORT", "5138")}"), desc: "HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_PORT. Default 5138."
        base.unique_option :key, type: :string, default: ENV.fetch("SPECWRK_SRV_KEY", ""), aliases: ["-k"], desc: "Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY. Default ''."
        base.unique_option :run, type: :string, default: ENV.fetch("SPECWRK_RUN", "main"), aliases: ["-r"], desc: "The run identifier for this job execution. Overrides SPECWRK_RUN. Default main."
        base.unique_option :timeout, type: :integer, default: ENV.fetch("SPECWRK_TIMEOUT", "5"), aliases: ["-t"], desc: "The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT. Default 5."
      end

      on_setup do |uri:, key:, run:, timeout:, **|
        ENV["SPECWRK_SRV_URI"] = uri
        ENV["SPECWRK_SRV_KEY"] = key
        ENV["SPECWRK_RUN"] = run
        ENV["SPECWRK_TIMEOUT"] = timeout
      end
    end

    module Workable
      extend Hookable

      on_included do |base|
        base.unique_option :id, type: :string, default: "specwrk-worker", desc: "The identifier for this worker. Default specwrk-worker(-COUNT_INDEX)."
        base.unique_option :count, type: :integer, default: 1, aliases: ["-c"], desc: "The number of worker processes you want to start. Default 1."
        base.unique_option :output, type: :string, default: ENV.fetch("SPECWRK_OUT", ".specwrk/"), aliases: ["-o"], desc: "Directory where worker output is stored. Overrides SPECWRK_OUT. Default '.specwrk/'."
      end

      on_setup do |id:, count:, output:, **|
        ENV["SPECWRK_ID"] = id
        ENV["SPECWRK_COUNT"] = count.to_s
        ENV["SPECWRK_OUT"] = Pathname.new(output).expand_path(Dir.pwd).to_s
      end

      def start_workers
        @worker_pids = worker_count.times.map do |i|
          Process.fork do
            ENV["TEST_ENV_NUMBER"] = ENV["SPECWRK_FORKED"] = (i + 1).to_s
            ENV["SPECWRK_ID"] = ENV["SPECWRK_ID"] + "-#{i + 1}"

            require "specwrk/worker"

            Specwrk::Worker.run!
          end
        end
      end

      def worker_count
        @worker_count ||= [1, ENV["SPECWRK_COUNT"].to_i].max
      end
    end

    module Servable
      extend Hookable

      on_included do |base|
        base.unique_option :port, type: :integer, default: ENV.fetch("SPECWRK_SRV_PORT", "5138"), aliases: ["-p"], desc: "Server port. Overrides SPECWRK_SRV_PORT. Default 5138."
        base.unique_option :key, type: :string, aliases: ["-k"], default: ENV.fetch("SPECWRK_SRV_KEY", ""), desc: "Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY. Default ''."
        base.unique_option :output, type: :string, default: ENV.fetch("SPECWRK_OUT", ".specwrk/"), aliases: ["-o"], desc: "Directory where worker output is stored. Overrides SPECWRK_OUT. Default '.specwrk/'."
        base.unique_option :group_by, values: %w[file timings], default: ENV.fetch("SPECWERK_SRV_GROUP_BY", "timings"), desc: "How examples will be grouped for workers; fallback to file if no timings are found. Overrides SPECWERK_SRV_GROUP_BY. Default timings."
        base.unique_option :single_run, type: :boolean, default: false, desc: "Act on shutdown requests from clients. Default: false."
        base.unique_option :verbose, type: :boolean, default: false, desc: "Run in verbose mode. Default false."
      end

      on_setup do |output:, port:, key:, single_run:, group_by:, verbose:, **|
        ENV["SPECWRK_SRV_LOG"] = Pathname.new(File.join(output, "server.log")).expand_path(Dir.pwd).to_s if output && !verbose
        ENV["SPECWRK_SRV_OUTPUT"] = Pathname.new(File.join(output, "report.json")).expand_path(Dir.pwd).to_s if output
        ENV["SPECWRK_SRV_PORT"] = port
        ENV["SPECWRK_SRV_KEY"] = key
        ENV["SPECWRK_SRV_SINGLE_RUN"] = "1" if single_run
        ENV["SPECWRK_SRV_GROUP_BY"] = group_by
      end
    end

    class Version < Dry::CLI::Command
      desc "Print version"

      def call(*)
        puts VERSION
      end
    end

    class Seed < Dry::CLI::Command
      include Clientable

      desc "Seed the server with a list of specs for the run"

      argument :dir, required: false, default: "spec", desc: "Relative spec directory to run against"

      def call(dir:, **args)
        self.class.setup(**args)

        require "specwrk/list_examples"
        require "specwrk/client"

        examples = ListExamples.new(dir).examples

        Client.wait_for_server!
        Client.new.seed(examples)
      rescue Errno::ECONNREFUSED
        puts "Server at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} is refusing connections, exiting...#{ENV["SPECWRK_FLUSH_DELIMINATOR"]}"
      rescue Errno::ECONNRESET
        puts "Server at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} stopped responding to connections, exiting...#{ENV["SPECWRK_FLUSH_DELIMINATOR"]}"
      end
    end

    class Work < Dry::CLI::Command
      include Workable
      include Clientable

      desc "Start one or more worker processes"

      def call(**args)
        self.class.setup(**args)

        start_workers
        Process.waitall

        require "specwrk/cli_reporter"
        status = Specwrk::CLIReporter.new.report

        exit(status)
      end
    end

    class Serve < Dry::CLI::Command
      include Servable

      desc "Start a queue server"

      def call(**args)
        self.class.setup(**args)

        require "specwrk/web"
        require "specwrk/web/app"

        Specwrk::Web::App.run!
      end
    end

    class Start < Dry::CLI::Command
      include Clientable
      include Workable
      include Servable

      desc "Start a server and workers, monitor until complete"
      argument :dir, required: false, default: "spec", desc: "Relative spec directory to run against"

      def call(dir:, **args)
        self.class.setup(**args)
        $stdout.sync = true

        web_pid = Process.fork do
          require "specwrk/web"
          require "specwrk/web/app"

          ENV["SPECWRK_FORKED"] = "1"
          ENV["SPECWRK_SRV_SINGLE_RUN"] = "1"
          status "Starting queue server..."
          Specwrk::Web::App.run!
        end

        return if Specwrk.force_quit
        seed_pid = Process.fork do
          require "specwrk/list_examples"
          require "specwrk/client"

          examples = ListExamples.new(dir).examples

          status "Waiting for server to respond..."
          Client.wait_for_server!
          status "Server responding ✓"
          status "Seeding #{examples.length} examples..."
          Client.new.seed(examples)
          status "Samples seeded ✓"
        end

        wait_for_pids_exit([seed_pid])

        return if Specwrk.force_quit
        status "Starting #{worker_count} workers..."
        start_workers

        status "#{worker_count} workers started ✓\n"
        wait_for_pids_exit(@worker_pids)

        return if Specwrk.force_quit

        require "specwrk/cli_reporter"
        status = Specwrk::CLIReporter.new.report

        wait_for_pids_exit([web_pid, seed_pid] + @worker_pids)
        exit(status)
      end

      def wait_for_pids_exit(pids)
        exited_pids = {}

        loop do
          pids.each do |pid|
            next if exited_pids.key? pid

            _, status = Process.waitpid2(pid, Process::WNOHANG)
            exited_pids[pid] = status.exitstatus if status&.exitstatus
          rescue Errno::ECHILD
            exited_pids[pid] = 0
          end

          break if exited_pids.keys.length == pids.length
          sleep 0.1
        end

        exited_pids
      end

      def status(msg)
        print "\e[2K\r#{msg}"
        $stdout.flush
      end
    end

    register "version", Version, aliases: ["v", "-v", "--version"]
    register "work", Work, aliases: ["wrk", "twerk", "w"]
    register "serve", Serve, aliases: ["srv", "s"]
    register "seed", Seed
    register "start", Start
  end
end
