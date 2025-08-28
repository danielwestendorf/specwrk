# frozen_string_literal: true

require "pathname"
require "securerandom"

require "dry/cli"

require "specwrk"
require "specwrk/hookable"

module Specwrk
  module CLI
    extend Dry::CLI::Registry

    module Clientable
      extend Hookable

      on_included do |base|
        base.unique_option :uri, type: :string, default: ENV.fetch("SPECWRK_SRV_URI", "http://localhost:#{ENV.fetch("SPECWRK_SRV_PORT", "5138")}"), desc: "HTTP URI of the server to pull jobs from. Overrides SPECWRK_SRV_URI"
        base.unique_option :key, type: :string, default: ENV.fetch("SPECWRK_SRV_KEY", ""), aliases: ["-k"], desc: "Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY"
        base.unique_option :run, type: :string, default: ENV.fetch("SPECWRK_RUN", "main"), aliases: ["-r"], desc: "The run identifier for this job execution. Overrides SPECWRK_RUN"
        base.unique_option :timeout, type: :integer, default: ENV.fetch("SPECWRK_TIMEOUT", "5"), aliases: ["-t"], desc: "The amount of time to wait for the server to respond. Overrides SPECWRK_TIMEOUT"
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
        base.unique_option :id, type: :string, desc: "The identifier for this worker. Overrides SPECWRK_ID. If none provided one in the format of specwrk-worker-8_RAND_CHARS-COUNT_INDEX will be used"
        base.unique_option :count, type: :integer, default: 1, aliases: ["-c"], desc: "The number of worker processes you want to start"
        base.unique_option :output, type: :string, default: ENV.fetch("SPECWRK_OUT", ".specwrk/"), aliases: ["-o"], desc: "Directory where worker output is stored. Overrides SPECWRK_OUT"
        base.unique_option :seed_waits, type: :integer, default: ENV.fetch("SPECWRK_SEED_WAITS", "10"), aliases: ["-w"], desc: "Number of times the worker will wait for examples to be seeded to the server. 1sec between attempts. Overrides SPECWRK_SEED_WAITS"
      end

      on_setup do |count:, output:, seed_waits:, id: "specwrk-worker-#{SecureRandom.uuid[0, 8]}", **|
        ENV["SPECWRK_ID"] ||= id # Unique default. Don't override the ENV value here

        ENV["SPECWRK_COUNT"] = count.to_s
        ENV["SPECWRK_SEED_WAITS"] = seed_waits.to_s
        ENV["SPECWRK_OUT"] = Pathname.new(output).expand_path(Dir.pwd).to_s
      end

      def start_workers
        @final_outputs = []
        @worker_pids = worker_count.times.map do |i|
          reader, writer = IO.pipe
          @final_outputs << reader

          Process.fork do
            ENV["TEST_ENV_NUMBER"] = ENV["SPECWRK_FORKED"] = (i + 1).to_s
            ENV["SPECWRK_ID"] = ENV["SPECWRK_ID"] + "-#{i + 1}"

            $final_output = writer # standard:disable Style/GlobalVars
            $final_output.sync = true # standard:disable Style/GlobalVars
            reader.close

            require "specwrk/worker"

            status = Specwrk::Worker.run!
            $final_output.close # standard:disable Style/GlobalVars
            exit(status)
          end.tap { writer.close }
        end
      end

      def drain_outputs
        @final_outputs.each do |reader|
          reader.each_line { |line| $stdout.print line }
          reader.close
        end
      end

      def worker_count
        @worker_count ||= [1, ENV["SPECWRK_COUNT"].to_i].max
      end
    end

    module Servable
      extend Hookable

      on_included do |base|
        base.unique_option :port, type: :integer, default: ENV.fetch("SPECWRK_SRV_PORT", "5138"), aliases: ["-p"], desc: "Server port. Overrides SPECWRK_SRV_PORT"
        base.unique_option :bind, type: :string, default: ENV.fetch("SPECWRK_SRV_BIND", "127.0.0.1"), aliases: ["-b"], desc: "Server bind address. Overrides SPECWRK_SRV_BIND"
        base.unique_option :key, type: :string, aliases: ["-k"], default: ENV.fetch("SPECWRK_SRV_KEY", ""), desc: "Authentication key clients must use for access. Overrides SPECWRK_SRV_KEY"
        base.unique_option :output, type: :string, default: ENV.fetch("SPECWRK_OUT", ".specwrk/"), aliases: ["-o"], desc: "Directory where worker or server output is stored. Overrides SPECWRK_OUT"
        base.unique_option :store_uri, type: :string, desc: "Directory where server state is stored. Required for multi-node or multi-process servers."
        base.unique_option :group_by, values: %w[file timings], default: ENV.fetch("SPECWERK_SRV_GROUP_BY", "timings"), desc: "How examples will be grouped for workers; fallback to file if no timings are found. Overrides SPECWERK_SRV_GROUP_BY"
        base.unique_option :verbose, type: :boolean, default: false, desc: "Run in verbose mode"
      end

      on_setup do |port:, bind:, output:, key:, group_by:, verbose:, **opts|
        ENV["SPECWRK_OUT"] = Pathname.new(output).expand_path(Dir.pwd).to_s
        ENV["SPECWRK_SRV_STORE_URI"] = opts[:store_uri] if opts.key? :store_uri
        ENV["SPECWRK_SRV_VERBOSE"] = "1" if verbose

        ENV["SPECWRK_SRV_PORT"] = port
        ENV["SPECWRK_SRV_BIND"] = bind
        ENV["SPECWRK_SRV_KEY"] = key
        ENV["SPECWRK_SRV_GROUP_BY"] = group_by
      end

      def find_open_port
        require "socket"

        server = TCPServer.new("127.0.0.1", 0)
        port = server.addr[1]
        server.close

        port
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
      option :max_retries, default: 0, desc: "Number of times an example will be re-run should it fail"
      argument :dir, type: :array, required: false, default: "spec", desc: "Relative spec directory to run against"

      def call(max_retries:, dir:, **args)
        self.class.setup(**args)

        require "specwrk/list_examples"
        require "specwrk/client"

        ENV["SPECWRK_SEED"] = "1"
        examples = ListExamples.new(dir).examples

        Client.wait_for_server!
        Client.new.seed(examples, max_retries)
        file_count = examples.group_by { |e| e[:file_path] }.keys.size
        puts "🌱 Seeded #{examples.size} examples across #{file_count} files"
      rescue Errno::ECONNREFUSED
        puts "Server at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} is refusing connections, exiting...#{ENV["SPECWRK_FLUSH_DELIMINATOR"]}"
        exit 1
      rescue Errno::ECONNRESET
        puts "Server at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} stopped responding to connections, exiting...#{ENV["SPECWRK_FLUSH_DELIMINATOR"]}"
        exit 1
      end
    end

    class Work < Dry::CLI::Command
      include Workable
      include Clientable

      desc "Start one or more worker processes"

      def call(**args)
        self.class.setup(**args)

        start_workers
        wait_for_workers_exit
        drain_outputs

        require "specwrk/cli_reporter"
        Specwrk::CLIReporter.new.report

        exit(status)
      end

      def wait_for_workers_exit
        @exited_pids = Specwrk.wait_for_pids_exit(@worker_pids)
      end

      def status
        @exited_pids.value?(1) ? 1 : 0
      end
    end

    class Serve < Dry::CLI::Command
      include Servable

      desc "Start a queue server"
      option :single_run, type: :boolean, default: false, desc: "Act on shutdown requests from clients"

      def call(single_run:, **args)
        ENV["SPECWRK_SRV_SINGLE_RUN"] = "1" if single_run

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
      option :max_retries, default: 0, desc: "Number of times an example will be re-run should it fail"
      argument :dir, required: false, type: :array, default: "spec", desc: "Relative spec directory to run against"

      def call(max_retries:, dir:, **args)
        self.class.setup(**args)
        $stdout.sync = true

        # nil this env var if it exists to prevent never-ending workers
        ENV["SPECWRK_SRV_URI"] = nil

        # Start on a random open port to not conflict with another server
        ENV["SPECWRK_SRV_PORT"] = find_open_port.to_s
        ENV["SPECWRK_SRV_URI"] = "http://localhost:#{ENV.fetch("SPECWRK_SRV_PORT", "5138")}"

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

          ENV["SPECWRK_FORKED"] = "1"
          ENV["SPECWRK_SEED"] = "1"
          examples = ListExamples.new(dir).examples

          status "Waiting for server to respond..."
          Client.wait_for_server!
          status "Server responding ✓"
          status "Seeding #{examples.length} examples..."
          Client.new.seed(examples, max_retries)
          file_count = examples.group_by { |e| e[:file_path] }.keys.size
          status "🌱 Seeded #{examples.size} examples across #{file_count} files"
        end

        if Specwrk.wait_for_pids_exit([seed_pid]).value?(1)
          Process.kill("INT", web_pid)
          exit(1)
        end

        return if Specwrk.force_quit
        status "Starting #{worker_count} workers..."
        start_workers

        status "#{worker_count} workers started ✓\n"
        Specwrk.wait_for_pids_exit(@worker_pids)

        drain_outputs
        return if Specwrk.force_quit

        require "specwrk/cli_reporter"
        status = Specwrk::CLIReporter.new.report

        Specwrk.wait_for_pids_exit([web_pid, seed_pid])
        exit(status)
      end

      def status(msg)
        print "\e[2K\r#{msg}"
        $stdout.flush
      end
    end

    class Watch < Dry::CLI::Command
      desc "Start a server and workers, watch for file changes in the current directory, and execute specs"
      option :watchfile, type: :string, default: "Specwrk.watchfile.rb", desc: "Path to watchfile configuration"
      option :count, type: :integer, default: 1, aliases: ["-c"], desc: "The number of worker processes you want to start"

      def call(count:, watchfile:, **args)
        $stdout.sync = true

        # nil this env var if it exists to prevent never-ending workers
        ENV["SPECWRK_SRV_URI"] = nil

        # Start on a random open port to not conflict with another server
        ENV["SPECWRK_SRV_PORT"] = find_open_port.to_s
        ENV["SPECWRK_SRV_URI"] = "http://localhost:#{ENV.fetch("SPECWRK_SRV_PORT", "5138")}"

        ENV["SPECWRK_SEED_WAITS"] = "0"
        ENV["SPECWRK_MAX_BUCKET_SIZE"] = "1"
        ENV["SPECWRK_COUNT"] = count.to_s
        ENV["SPECWRK_RUN"] = "watch"

        web_pid

        return if Specwrk.force_quit

        seed_pid

        start_watcher(watchfile)

        require "specwrk/cli_reporter"

        title "👀 for changes"

        loop do
          status "👀 Watching for file changes..."

          @worker_pids = nil
          Thread.pass until file_queue.length.positive? || Specwrk.force_quit

          break if Specwrk.force_quit

          files = []
          files.push(file_queue.pop) until file_queue.length.zero?
          status "Running specs for #{files.join(" ")}..."
          ipc.write(files.join(" "))

          example_count = ipc.read.to_i
          if example_count.positive?
            puts "\n🌱 Seeded #{example_count} examples for execution\n"
          else
            puts "\n🙅 No examples to seed for execution\n"
          end

          next if example_count.zero?
          title "👷 on #{example_count} examples"

          return if Specwrk.force_quit
          start_workers

          Specwrk.wait_for_pids_exit(@worker_pids)

          drain_outputs
          return if Specwrk.force_quit

          reporter = Specwrk::CLIReporter.new

          status = reporter.report
          puts

          if status.zero?
            title "🟢 #{reporter.example_count} examples passed"
          else
            title " 🔴 #{reporter.failure_count}/#{reporter.example_count} examples failed"
          end

          $stdout.flush
        end

        ipc.write "INT" # wakes the socket
        Specwrk.wait_for_pids_exit([web_pid, seed_pid])
      end

      private

      def title(str)
        $stdout.write "\e]0;#{str}\a"
        $stdout.flush
      end

      def web_pid
        @web_pid ||= Process.fork do
          require "specwrk/web"
          require "specwrk/web/app"

          ENV["SPECWRK_FORKED"] = "1"
          status "Starting queue server..."
          Specwrk::Web::App.run!
        end
      end

      def seed_pid
        @seed_pid ||= begin
          ipc # must be initialized in the parent process

          @seed_pid = Process.fork do
            require "specwrk/seed_loop"

            ENV["SPECWRK_FORKED"] = "1"
            ENV["SPECWRK_SEED"] = "1"

            Specwrk::SeedLoop.loop!(ipc)
          end
        end
      end

      def ipc
        @ipc ||= begin
          require "specwrk/ipc"

          Specwrk::IPC.new
        end
      end

      def start_watcher(watchfile)
        require "specwrk/watcher"

        Specwrk::Watcher.watch(Dir.pwd, file_queue, watchfile)
      end

      def file_queue
        @file_queue ||= Queue.new
      end

      def status(msg)
        print "\e[2K\r#{msg}"
        $stdout.flush
      end

      def start_workers
        @final_outputs = []
        @worker_pids = worker_count.times.map do |i|
          reader, writer = IO.pipe
          @final_outputs << reader

          Process.fork do
            ENV["TEST_ENV_NUMBER"] = ENV["SPECWRK_FORKED"] = (i + 1).to_s
            ENV["SPECWRK_ID"] = "specwrk-worker-#{i + 1}"

            $final_output = writer # standard:disable Style/GlobalVars
            $final_output.sync = true # standard:disable Style/GlobalVars
            reader.close

            require "specwrk/worker"

            status = Specwrk::Worker.run!
            $final_output.close # standard:disable Style/GlobalVars
            exit(status)
          end.tap { writer.close }
        end
      end

      def drain_outputs
        @final_outputs.each do |reader|
          reader.each_line { |line| $stdout.print line }
          reader.close
        end
      end

      def worker_count
        @worker_count ||= [1, ENV["SPECWRK_COUNT"].to_i].max
      end

      def find_open_port
        require "socket"

        server = TCPServer.new("127.0.0.1", 0)
        port = server.addr[1]
        server.close

        port
      end
    end

    register "version", Version, aliases: ["v", "-v", "--version"]
    register "work", Work, aliases: ["wrk", "twerk", "w"]
    register "serve", Serve, aliases: ["srv", "s"]
    register "seed", Seed
    register "start", Start
    register "watch", Watch, aliases: ["w", "👀"]
  end
end
