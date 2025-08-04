# frozen_string_literal: true

require "specwrk/store/memory_adapter"

RSpec.describe Specwrk::Store::MemoryAdapter do
  let(:instance) { described_class.new("memory:///foobar", "baz") }

  before { described_class.clear }

  describe "#[]=" do
    subject { instance["foo"] = "bar" }

    it { expect { subject }.to change { instance["foo"] }.from(nil).to("bar") }
  end

  describe "#[]" do
    subject { instance[key] }

    let(:key) { "hello" }

    before { instance[key] = "world" }

    it { is_expected.to eq("world") }
  end

  describe "#keys" do
    subject { instance.keys }

    before do
      instance["a"] = 1
      instance["b"] = 2
    end

    it { is_expected.to match_array(%w[a b]) }
  end

  describe "#clear" do
    subject { instance.clear }

    before { instance["foo"] = "bar" }

    it { expect { subject }.to change(instance, :empty?).from(false).to(true) }
  end

  describe "#delete" do
    subject { instance.delete("one", "two") }

    before do
      instance["one"] = 1
      instance["two"] = 2
    end

    it { expect { subject }.to change { instance.keys }.from(%w[one two]).to([]) }
  end

  describe "#merge! and #multi_write" do
    subject { instance.merge!(b: 1, a: 2) }

    it { expect { subject }.to change { instance[:a] }.from(nil).to(2) }
    it { expect { subject }.to change { instance[:b] }.from(nil).to(1) }
  end

  describe "#multi_read" do
    subject { instance.multi_read("a", "c") }

    before { instance.merge!("a" => 1, "b" => 2, "c" => 3) }

    it { is_expected.to eq("a" => 1, "c" => 3) }
  end

  describe "#empty?" do
    subject { instance.empty? }

    context "when store is empty" do
      it { is_expected.to be true }
    end

    context "when store has data" do
      before { instance["key"] = "value" }

      it { is_expected.to be false }
    end
  end
end
