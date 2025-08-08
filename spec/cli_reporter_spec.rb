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
        let(:flake_count) { 0 }
        let(:unexecuted_count) { 0 }
        let(:example_count) { 100 }
        let(:report_data) do
          {
            examples: {
              "a.rb:73": {status: "failed", file_path: "a.rb", line_number: 73, full_description: "Broken test"},
              "b.rb:4": {status: "passed"}
            }
          }
        end

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
          allow(instance).to receive(:flake_count)
            .and_return(flake_count)
          allow(instance).to receive(:unexecuted_count)
            .and_return(unexecuted_count)
          allow(instance).to receive(:example_count)
            .and_return(example_count)

          allow(instance).to receive(:report_data)
            .and_return(report_data)

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
            expect(instance).to receive(:puts).with("")
            expect(subject).to eq(1)
          end
        end

        context "client returns report data with positive unexecuted_count count" do
          let(:unexecuted_count) { 1 }

          it "prints finish summary and totals line then returns 1" do
            expect(instance).to receive(:puts).with("\nFinished in 2.5s (total execution time of 5s)\n")
            expect(instance).to receive(:puts).with("\e[31m100 examples, 0 failures. 1 example not executed\e[0m")
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
          let(:flake_count) { 1 }

          let(:report_data) do
            {
              examples: {
                "a.rb:73": {status: "failed", file_path: "a.rb", line_number: 73, full_description: "Broken test"},
                "b.rb:4": {status: "passed", file_path: "b.rb", line_number: 42, full_description: "Passing test"}
              },
              flakes: {
                "b.rb:4": 6
              }
            }
          end

          it "prints finish summary and totals line then returns 0" do
            expect(instance).to receive(:puts).with("\nFlaked examples:\n\n")
            expect(instance).to receive(:print).with("\e[35mrspec b.rb:42\e[0m \e[36m# Passing test. Failed 6 times before passing.\e[0m\n")
            expect(instance).to receive(:puts).with("")
            expect(instance).to receive(:puts).with("\nFinished in 2.5s (total execution time of 5s)\n")
            expect(instance).to receive(:puts).with("\e[32m100 examples, 0 failures, 1 example flaked 6 times\e[0m")
            expect(subject).to eq(0)
          end
        end
      end
    end
  end
end
