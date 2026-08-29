# frozen_string_literal: true

RSpec.describe Specwrk::Hooks do
  describe ".register" do
    it "registers multiple hooks under a name in order" do
      calls = []

      described_class.register(:before_work) { calls << :first }
      described_class.register(:before_work) { calls << :second }

      described_class.run(:before_work)

      expect(calls).to eq([:first, :second])
    end

    it "returns the registered block" do
      hook = proc {}

      expect(described_class.register(:before_work, &hook)).to be(hook)
    end

    it "requires a block" do
      expect { described_class.register(:before_work) }
        .to raise_error(ArgumentError, "a block is required")
    end
  end

  describe ".run" do
    it "does nothing for an unregistered name" do
      expect(described_class.run(:unregistered)).to be_nil
    end

    it "forwards zero positional objects" do
      received = :not_called
      described_class.register(:before_work) { |*objects| received = objects }

      described_class.run(:before_work)

      expect(received).to eq([])
    end

    it "forwards one positional object by identity" do
      object = Object.new
      received = nil
      described_class.register(:before_work) { |value| received = value }

      described_class.run(:before_work, object)

      expect(received).to be(object)
    end

    it "forwards multiple positional objects by identity" do
      first = Object.new
      second = Object.new
      received = nil
      described_class.register(:before_work) { |*objects| received = objects }

      described_class.run(:before_work, first, second)

      expect(received[0]).to be(first)
      expect(received[1]).to be(second)
    end

    it "ignores hook return values and returns nil" do
      described_class.register(:before_work) { :hook_result }

      expect(described_class.run(:before_work)).to be_nil
    end

    it "propagates the first exception and skips remaining hooks" do
      calls = []
      error = Class.new(StandardError)
      described_class.register(:before_work) do
        calls << :first
        raise error, "hook failed"
      end
      described_class.register(:before_work) { calls << :second }

      expect { described_class.run(:before_work) }
        .to raise_error(error, "hook failed")
      expect(calls).to eq([:first])
    end

    it "does not run hooks registered during execution until the next run" do
      calls = []
      added = false
      described_class.register(:before_work) do
        calls << :first
        next if added

        added = true
        described_class.register(:before_work) { calls << :added }
      end

      described_class.run(:before_work)
      expect(calls).to eq([:first])

      described_class.run(:before_work)
      expect(calls).to eq([:first, :first, :added])
    end
  end

  describe ".reset!" do
    it "clears registered hooks" do
      calls = []
      described_class.register(:before_work) { calls << :called }

      described_class.reset!
      described_class.run(:before_work)

      expect(calls).to be_empty
    end
  end
end
