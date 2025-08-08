# frozen_string_literal: true

require "specwrk/cli_reporter"

RSpec.describe Specwrk::CLIReporter do
  before { allow($stdout).to receive(:tty?).and_return(true) }

  describe "#report" do
    describe "#report" do
      subject { instance.report }

      let(:instance) { described_class.new }

      context "client cannot connect" do
        before do
          allow(Specwrk::Client).to receive(:connect?).and_return(false)
        end

        it "prints failure message and returns 1" do
          expect(instance).to receive(:puts)
            .with("\e[31m\nCannot connect to server to generate report. Assuming failure.\e[0m")
          expect(subject).to eq(1)
        end
      end

      context "client responds with error" do
        before do
          allow(Specwrk::Client).to receive(:connect?)
            .and_return(true)

          allow(instance).to receive(:client)
            .and_return(double(shutdown: nil))

          allow(instance).to receive(:report_data)
            .and_raise(Specwrk::UnhandledResponseError.new("fff"))
        end

        it "prints no examples run message and returns 1" do
          expect(instance).to receive(:puts).with("\e[31m\nCannot report, fff.\e[0m")
          expect(subject).to eq(1)
        end
      end

      context "client responds" do
        let(:total_duration) { 2.5 }
        let(:total_run_time) { 5.0 }
        let(:failure_count) { 0 }
        let(:pending_count) { 0 }
        let(:example_count) { 100 }

        before do
          allow(Specwrk::Client).to receive(:connect?)
            .and_return(true)

          allow(instance).to receive(:total_duration)
            .and_return(total_duration)
          allow(instance).to receive(:total_run_time)
            .and_return(total_run_time)
          allow(instance).to receive(:failure_count)
            .and_return(failure_count)
          allow(instance).to receive(:pending_count)
            .and_return(pending_count)
          allow(instance).to receive(:example_count)
            .and_return(example_count)

          allow(instance).to receive(:report_data)
            .and_return({examples: {
              "a.rb:73": {status: "failed", file_path: "a.rb", line_number: 73, full_description: "Broken test"},
              "b.rb:4": {status: "passed"}
            }})

          allow(instance).to receive(:client)
            .and_return(double(shutdown: nil))
        end

        context "client returns report data with positive failure count" do
          let(:failure_count) { 1 }

          it "prints finish summary and totals line then returns 1" do
            expect(instance).to receive(:puts).with("\nFinished in 2.5s (total execution time of 5s)\n")
            expect(instance).to receive(:puts).with("\e[31m100 examples, 1 failure\e[0m")
            expect(instance).to receive(:puts).with("\nFailed examples:\n\n")
            expect(instance).to receive(:print).with("\e[31mrspec a.rb:73\e[0m \e[36m# Broken test\e[0m\n")
            expect(instance).to receive(:puts)
            expect(subject).to eq(1)
          end
        end

        context "client returns report data with positive pending count" do
          let(:pending_count) { 2 }

          it "prints finish summary and totals line then returns 0" do
            expect(instance).to receive(:puts)
              .with("\nFinished in 2.5s (total execution time of 5s)\n")
            expect(instance).to receive(:puts)
              .with("\e[33m100 examples, 0 failures, 2 pending\e[0m")
            expect(subject).to eq(0)
          end
        end

        context "client returns report data with all passed" do
          it "prints finish summary and totals line then returns 0" do
            expect(instance).to receive(:puts)
              .with("\nFinished in 2.5s (total execution time of 5s)\n")
            expect(instance).to receive(:puts).with("\e[32m100 examples, 0 failures\e[0m")
            expect(subject).to eq(0)
          end
        end
      end
    end
  end
end
