# frozen_string_literal: true

require "specwrk/cli"

RSpec.describe Specwrk::CLI::WorkerProcesses do
  let(:instance) { Class.new { include Specwrk::CLI::WorkerProcesses }.new }

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
