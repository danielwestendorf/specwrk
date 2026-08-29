# frozen_string_literal: true

require "tempfile"

require "specwrk/cli"

RSpec.describe Specwrk::CLI::WorkerProcesses do
  let(:instance) { Class.new { include Specwrk::CLI::WorkerProcesses }.new }

  describe "#start_workers" do
    it "runs before_worker_fork in the parent before each worker spawn" do
      parent_pid = Process.pid
      calls = []
      readers = Array.new(2) { instance_double(IO) }
      writers = Array.new(2) { instance_double(IO, fileno: 42, close: nil) }

      allow(instance).to receive(:worker_count).and_return(2)
      allow(IO).to receive(:pipe).and_return(
        [readers[0], writers[0]],
        [readers[1], writers[1]]
      )
      allow(Process).to receive(:spawn) do
        calls << [:spawn, Process.pid]
        123
      end
      Specwrk.before_worker_fork { calls << [:hook, Process.pid] }

      instance.start_workers

      expect(calls).to eq([
        [:hook, parent_pid],
        [:spawn, parent_pid],
        [:hook, parent_pid],
        [:spawn, parent_pid]
      ])
    end

    it "runs after_worker_fork inside the spawned child process" do
      parent_pid = Process.pid

      Tempfile.create(["after_worker_fork", ".rb"]) do |setup|
        Tempfile.create("after_worker_fork_output") do |output|
          setup.write <<~RUBY
            require "specwrk"

            Specwrk.after_worker_fork do
              File.write(ENV.fetch("AFTER_WORKER_FORK_OUTPUT"), Process.pid)
              exit(0)
            end
          RUBY
          setup.flush

          reader, writer = IO.pipe
          rubyopt = [ENV["RUBYOPT"], "-r#{setup.path}"].compact.join(" ")
          pid = Process.spawn(
            {
              "AFTER_WORKER_FORK_OUTPUT" => output.path,
              "RUBYOPT" => rubyopt,
              "SPECWRK_FINAL_FD" => writer.fileno.to_s
            },
            RbConfig.ruby,
            "-I", File.expand_path("../../lib", __dir__),
            "-e", described_class::WORKER_INIT_SCRIPT,
            writer.fileno => writer,
            :err => File::NULL,
            :close_others => false
          )
          writer.close

          _, status = Process.wait2(pid)
          reader.close
          output.rewind

          expect(status).to be_success
          expect(output.read).to eq(pid.to_s)
          expect(pid).not_to eq(parent_pid)
        end
      end
    end
  end

  describe "#worker_env_for" do
    it "leaves the first worker's TEST_ENV_NUMBER blank, parallel_tests-style" do
      expect(instance.worker_env_for(1)).to include("TEST_ENV_NUMBER" => "")
    end

    it "numbers the remaining workers from 2" do
      expect(instance.worker_env_for(2)).to include("TEST_ENV_NUMBER" => "2")
      expect(instance.worker_env_for(3)).to include("TEST_ENV_NUMBER" => "3")
    end
  end
end
