# frozen_string_literal: true

require "specwrk/cli"
require "specwrk/cli_reporter"

RSpec.describe Specwrk::CLI::Start do
  subject(:call) { command.call(max_retries: 0, dir: ["spec"]) }

  let(:command) { described_class.new }
  let(:web_pid) { 123 }
  let(:seed_pid) { 456 }
  let(:worker_pids) { [789, 790] }
  let(:reporter) { instance_double(Specwrk::CLIReporter, report: exit_status) }
  let(:exit_status) { 0 }
  let(:hook) { spy("completion hook") }

  before do
    stub_const("ENV", ENV.to_h)
    allow(described_class).to receive(:setup)
    allow(Specwrk).to receive(:force_quit).and_return(false)
    allow(command).to receive(:find_open_port).and_return(5138)
    allow(command).to receive(:status)
    allow(Process).to receive(:fork).and_return(web_pid)
    allow(command).to receive(:spawn_seed_process).and_return(seed_pid)
    allow(command).to receive(:start_workers) do
      command.instance_variable_set(:@worker_pids, worker_pids)
    end
    allow(command).to receive(:drain_outputs)
    allow(Specwrk).to receive(:wait_for_pids_exit).with([seed_pid]).and_return(seed_pid => 0)
    allow(Specwrk).to receive(:wait_for_pids_exit).with(worker_pids).and_return(789 => 0, 790 => 0)
    allow(Specwrk).to receive(:wait_for_pids_exit).with([web_pid, seed_pid]).and_return(web_pid => 0, seed_pid => 0)
    allow(Specwrk::CLIReporter).to receive(:new).and_return(reporter)
  end

  [0, 1].each do |status|
    context "when the final report returns #{status}" do
      let(:exit_status) { status }

      it "runs the hook once in the parent after workers, output, reporting, and shutdown" do
        Specwrk.after_start_complete { |value| hook.call(value, Process.pid) }

        expect(Specwrk).to receive(:wait_for_pids_exit).with(worker_pids).ordered
        expect(command).to receive(:drain_outputs).ordered
        expect(reporter).to receive(:report).ordered.and_return(exit_status)
        expect(Specwrk).to receive(:wait_for_pids_exit).with([web_pid, seed_pid]).ordered
        expect(hook).to receive(:call).with(exit_status, Process.pid).once.ordered

        expect { call }.to raise_error(SystemExit) { |error| expect(error.status).to eq(exit_status) }
      end
    end
  end

  it "preserves the exit status when no hook is registered" do
    expect { call }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
  end

  it "ignores the hook's return value" do
    Specwrk.after_start_complete { 42 }

    expect { call }.to raise_error(SystemExit) { |error| expect(error.status).to eq(0) }
  end

  it "propagates hook exceptions" do
    Specwrk.after_start_complete { raise "coverage failed" }

    expect { call }.to raise_error(RuntimeError, "coverage failed")
  end

  it "does not run the hook when seeding fails" do
    Specwrk.after_start_complete { |status| hook.call(status) }
    allow(Specwrk).to receive(:wait_for_pids_exit).with([seed_pid]).and_return(seed_pid => 1)
    expect(Process).to receive(:kill).with("INT", web_pid)

    expect { call }.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
    expect(hook).not_to have_received(:call)
    expect(reporter).not_to have_received(:report)
  end

  it "does not run the hook when the run is interrupted" do
    Specwrk.after_start_complete { |status| hook.call(status) }
    allow(Specwrk).to receive(:force_quit).and_return(false, false, true)

    expect(call).to be_nil
    expect(hook).not_to have_received(:call)
    expect(reporter).not_to have_received(:report)
  end
end
