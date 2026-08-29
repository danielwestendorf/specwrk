# frozen_string_literal: true

require "tmpdir"

require "specwrk/cli"

RSpec.describe Specwrk::CLI::WorkerProcesses do
  let(:instance) { Class.new { include Specwrk::CLI::WorkerProcesses }.new }

  def run_worker_with(setup_source)
    Dir.mktmpdir("worker_hooks") do |dir|
      setup_path = File.join(dir, "setup.rb")
      output_path = File.join(dir, "output")
      File.write(setup_path, setup_source)

      reader, writer = IO.pipe
      rubyopt = [ENV["RUBYOPT"], "-r#{setup_path}"].compact.join(" ")
      pid = Process.spawn(
        {
          "RUBYOPT" => rubyopt,
          "SPECWRK_FINAL_FD" => writer.fileno.to_s,
          "WORKER_HOOK_OUTPUT" => output_path
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

      {pid: pid, status: status, output: File.read(output_path)}
    end
  end

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
      result = run_worker_with <<~RUBY
        require "specwrk"

        Specwrk.after_worker_fork do
          File.write(ENV.fetch("WORKER_HOOK_OUTPUT"), Process.pid)
          exit(0)
        end
      RUBY

      expect(result[:status]).to be_success
      expect(result[:output]).to eq(result[:pid].to_s)
      expect(result[:pid]).not_to eq(parent_pid)
    end

    it "runs before_worker_exit inside the worker after work completes" do
      result = run_worker_with <<~RUBY
        require "specwrk"
        require "specwrk/worker"

        Specwrk::Worker.define_singleton_method(:run!) do
          File.write(ENV.fetch("WORKER_HOOK_OUTPUT"), "run")
          0
        end

        Specwrk.before_worker_exit do |status|
          File.open(ENV.fetch("WORKER_HOOK_OUTPUT"), "a") do |file|
            file.write(":hook:")
            file.write(status)
            file.write(":")
            file.write(Process.pid)
          end
        end
      RUBY

      expect(result[:status]).to be_success
      expect(result[:output]).to eq("run:hook:0:#{result[:pid]}")
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

RSpec.describe Specwrk::CLI::Work do
  describe "#wait_for_workers_exit" do
    it "runs after_all_workers_exit with the status after all workers exit" do
      instance = described_class.new
      worker_pids = [123, 456]
      exited_pids = {123 => 0, 456 => 1}
      instance.instance_variable_set(:@worker_pids, worker_pids)
      allow(Specwrk).to receive(:wait_for_pids_exit).with(worker_pids).and_return(exited_pids)
      received = nil
      Specwrk.after_all_workers_exit { |status| received = status }

      expect(instance.wait_for_workers_exit).to be(exited_pids)
      expect(received).to eq(instance.status)
    end
  end
end
