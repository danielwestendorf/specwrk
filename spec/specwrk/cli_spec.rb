# frozen_string_literal: true

require "specwrk/cli"

RSpec.describe Specwrk::CLI::Work do
  describe "#status" do
    subject { instance.status }

    let(:instance) { described_class.new }

    before { instance.instance_variable_set(:@exited_pids, exited_pids) }

    context "when every worker exited cleanly" do
      let(:exited_pids) { {123 => 0, 456 => 0} }

      it { is_expected.to eq(0) }
    end

    context "when a worker exited with status 1" do
      let(:exited_pids) { {123 => 0, 456 => 1} }

      it { is_expected.to eq(1) }
    end

    context "when a worker exited with its failure count as the status" do
      let(:exited_pids) { {123 => 0, 456 => 7} }

      it { is_expected.to eq(1) }
    end
  end
end
