# frozen_string_literal: true

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
