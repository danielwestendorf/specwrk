# frozen_string_literal: true

require "specwrk/worker"

RSpec.describe Specwrk::Worker do
  let(:client) { instance_double(Specwrk::Client, close: true, fetch_examples: %w[a.rb:1 b.rb:2]) }
  let(:executor) { instance_double(Specwrk::Worker::Executor, final_output: tempfile, examples: %w[a.rb:1 b.rb:2]) }
  let(:tempfile) { instance_double(Tempfile, rewind: true) }
  let(:thread) { instance_double(Thread, kill: true) }

  let(:instance) { described_class.new }

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

      it "warns and exits cleanly" do
        expect(instance).to receive(:warn)

        expect { subject }.not_to raise_error
      end
    end

    context "server connection reset" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!).and_raise(Errno::ECONNRESET) }

      it "warns and exits cleanly" do
        expect(instance).to receive(:warn)

        expect { subject }.not_to raise_error
      end
    end

    context "Specwrk.force_quit" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "breaks the loop" do
        count = 0
        expect(instance).to receive(:execute).exactly(4).times
        expect(Specwrk).to receive(:force_quit).exactly(5).times do
          count += 1
          count == 5
        end

        expect($stdout).to receive(:write)
          .with("foo")
        expect($stdout).to receive(:write)
          .with("bar")

        expect { subject }.not_to raise_error
      end
    end

    context "calls run_examples until CompletedAllExamplesError" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "breaks the loop" do
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

        expect { subject }.not_to raise_error
      end
    end

    context "calls run_examples until NoMoreExamplesError" do
      before { allow(Specwrk::Client).to receive(:wait_for_server!) }

      it "sleeps but doesn't break loop" do
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
            raise Specwrk::CompletedAllExamplesError
          end
        end

        expect($stdout).to receive(:write)
          .with("foo")
        expect($stdout).to receive(:write)
          .with("bar")

        expect { subject }.not_to raise_error
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

        allow(instance).to receive(:sleep)
          .with(1)
          .and_raise("Boom")
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

      it "last request > 10 sec ago" do
        allow(client).to receive(:last_request_at)
          .and_return(Time.now - 11)

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
