# frozen_string_literal: true

RSpec.describe Specwrk do
  it "has a version number" do
    expect(Specwrk::VERSION).not_to be nil
  end

  describe ".wait_for_pids_exit" do
    subject { described_class.wait_for_pids_exit(pids) }

    let(:pids) { [pid1, pid2] }

    let(:pid1) do
      fork do
        sleep 0.1
        exit 0
      end
    end

    let(:pid2) do
      fork do
        sleep 0.2
        exit 42
      end
    end

    context "returns exit statuses for all PIDs" do
      let(:pids) { [pid1, pid2] }

      it { is_expected.to eq(pid1 => 0, pid2 => 42) }
    end

    context "handles Errno::ECHILD when a PID has already been reaped" do
      before { Process.wait(pid1) } # Causes Errno::ECHILD to raise

      it { is_expected.to eq(pid1 => 1, pid2 => 42) }
    end
  end
end
