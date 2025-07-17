# frozen_string_literal: true

require "specwrk/worker"

RSpec.describe Specwrk::Worker do
  let(:client) { instance_double(Specwrk::Client, close: true, fetch_examples: %w[a.rb:1 b.rb:2]) }
  let(:tempfile) { instance_double(Tempfile, rewind: true) }
  let(:thread) { instance_double(Thread, kill: true) }

  let(:instance) { described_class.new }
  let(:failure) { false }
  let(:example_processed) { true }

  let(:executor) do
    instance_double Specwrk::Worker::Executor,
      final_output: tempfile,
      examples: %w[a.rb:1 b.rb:2],
      failure: failure,
      example_processed: example_processed
  end

  before do
    allow(Specwrk::Client).to receive(:new)
      .and_return(client)
    allow(Specwrk::Worker::Executor).to receive(:new)
      .and_return(executor)

    allow(Thread).to receive(:new)
      .and_return(thread)

    allow(tempfile).to receive(:each_line)
      .and_yield("foo")
      .and_yield("bar")
  end

  describe ".run!" do
    subject { described_class.run! }

    it "delegates to #run" do
      expect(described_class).to receive(:new)
        .and_return(instance)
      expect(instance).to receive(:run)

      described_class.run!
    end
  end

  describe "#run" do
    subject { instance.run }

    context "server connection refused" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!).and_raise(Errno::ECONNREFUSED) }

      it "warns and exits status 1" do
        expect(instance).to receive(:warn)
          .with(a_string_including("refusing connections"))

        expect(subject).to eq(1)
      end
    end

    context "server connection reset" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!).and_raise(Errno::ECONNRESET) }

      it "warns and exits with status 1" do
        expect(instance).to receive(:warn)
          .with(a_string_including("stopped responding"))

        expect(subject).to eq(1)
      end
    end

    context "no examples processed" do
      let(:example_processed) { nil }

      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "returns 0 when no examples were processed, but server signals all examples completed" do
        expect(instance).to receive(:execute)
          .and_raise(Specwrk::CompletedAllExamplesError)

        expect(subject).to eq(0)
      end

      it "returns 1 when no examples were processed, but server did not signal all examples completed" do
        expect(instance).to receive(:sleep)
          .with(1)
          .exactly(10).times

        expect(instance).to receive(:warn)
          .exactly(11).times

        expect(instance).to receive(:execute)
          .and_raise(Specwrk::WaitingForSeedError)
          .exactly(11).times

        expect(subject).to eq(1)
      end
    end

    context "Specwrk.force_quit" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "breaks the loop" do
        count = 0
        expect(instance).to receive(:execute).exactly(4).times
        expect(Specwrk).to receive(:force_quit).exactly(6).times do
          count += 1
          count >= 5
        end

        expect($stdout).to receive(:write)
          .with("foo")
        expect($stdout).to receive(:write)
          .with("bar")

        expect(subject).to eq(1)
      end
    end

    context "calls run_examples until CompletedAllExamplesError" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "breaks the loop and returns 0" do
        count = 1
        expect(instance).to receive(:execute).exactly(5).times do
          if count == 5
            raise Specwrk::CompletedAllExamplesError
          end

          count += 1
        end

        expect($stdout).to receive(:write)
          .with("foo")
        expect($stdout).to receive(:write)
          .with("bar")

        expect(subject).to eq(0)
      end
    end

    context "calls run_examples when WaitingForSeedError" do
      let(:example_processed) { nil }

      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "waits up to 10s before exiting" do
        expect(instance).to receive(:sleep)
          .with(1)
          .exactly(10).times

        expect(instance).to receive(:execute)
          .and_raise(Specwrk::WaitingForSeedError)
          .exactly(11).times

        expect(instance).to receive(:warn)
          .with("No examples seeded yet, waiting...")
          .exactly(10).times

        expect(instance).to receive(:warn)
          .with("No examples seeded, giving up!")

        expect(subject).to eq(1)
      end
    end

    context "calls run_examples until NoMoreExamplesError" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "sleeps but doesn't break loop" do
        completed = false
        expect(instance).to receive(:sleep)
          .with(0.5)
          .exactly(4).times

        count = 0
        expect(instance).to receive(:execute).exactly(5).times do
          count += 1

          if count < 5
            raise Specwrk::NoMoreExamplesError
          else
            # breaks the loop
            completed = true
            raise Specwrk::CompletedAllExamplesError
          end
        end

        expect($stdout).to receive(:write)
          .with("foo")
        expect($stdout).to receive(:write)
          .with("bar")

        expect(subject).to eq(0)
        expect(completed).to eq(true) # ensures the loop was broken in the way we expected
      end
    end
  end

  describe "#execute" do
    it "tries fetching examples, executing them, and completing them" do
      expect(executor).to receive(:run)
        .with(client.fetch_examples)

      expect(instance).to receive(:complete_examples)

      instance.execute
    end

    it "warns when an unhandled error is raised" do
      expect(client).to receive(:fetch_examples)
        .and_raise(Specwrk::UnhandledResponseError, "oops")

      expect(executor).not_to receive(:run)
      expect(instance).not_to receive(:complete_examples)

      expect(instance).to receive(:warn)
        .with("oops")

      instance.execute
    end
  end

  describe "#complete_examples" do
    it "tries completing examples" do
      expect(client).to receive(:complete_examples).with(executor.examples)

      instance.complete_examples
    end

    it "tries completing examples again when an unhandled error is raised" do
      expect(client).to receive(:complete_examples).with(executor.examples)
        .and_raise(Specwrk::UnhandledResponseError, "oops")
        .ordered

      expect(client).to receive(:complete_examples).with(executor.examples)
        .ordered

      expect(instance).to receive(:warn)
        .with("oops")
      expect(instance).to receive(:sleep)
        .with(1)

      instance.complete_examples
    end
  end

  describe "#thump" do
    context "while running and not force_quit" do
      before do
        allow(instance).to receive(:running)
          .and_return(true)

        allow(Specwrk).to receive(:force_quit)
          .and_return(false)

        sleep_count = 0

        allow(instance).to receive(:sleep).with(10) do
          raise "Boom" if sleep_count == 1
          sleep_count += 1
        end
      end

      it "last request nil" do
        allow(client).to receive(:last_request_at)
          .and_return(nil)

        expect(client).to receive(:heartbeat)
          .and_return(true)

        expect { instance.thump }.to raise_error("Boom")
      end

      it "last request < 10 sec ago" do
        allow(client).to receive(:last_request_at)
          .and_return(Time.now - 1)

        expect(client).not_to receive(:heartbeat)

        expect { instance.thump }.to raise_error("Boom")
      end

      it "last request > 30 sec ago" do
        allow(client).to receive(:last_request_at)
          .and_return(Time.now - 31)

        expect(client).to receive(:heartbeat)
          .and_return(true)

        expect { instance.thump }.to raise_error("Boom")
      end

      it "heartbeat raises an error" do
        allow(client).to receive(:last_request_at)
          .and_return(nil)

        expect(client).to receive(:heartbeat)
          .and_raise("Bang!")

        expect(instance).to receive(:warn)
          .with("Heartbeat failed!")

        expect { instance.thump }.to raise_error("Boom")
      end
    end

    context "while not running and not force_quit" do
      before do
        allow(instance).to receive(:running)
          .and_return(false)

        allow(Specwrk).to receive(:force_quit)
          .and_return(false)
      end

      it "does not heartbeat" do
        expect(client).not_to receive(:last_request_at)
        expect(client).not_to receive(:heartbeat)

        instance.thump
      end
    end

    context "while running and force_quit" do
      before do
        allow(instance).to receive(:running)
          .and_return(true)

        allow(Specwrk).to receive(:force_quit)
          .and_return(true)
      end

      it "does not heartbeat" do
        expect(client).not_to receive(:last_request_at)
        expect(client).not_to receive(:heartbeat)

        instance.thump
      end
    end
  end
end
