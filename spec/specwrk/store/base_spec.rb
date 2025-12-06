# frozen_string_literal: true

require "tempfile"
require "securerandom"

require "specwrk/store"

RSpec.describe Specwrk::Store do
  describe ".adapter_klass" do
    subject { described_class.adapter_klass(uri) }

    context "memory" do
      let(:uri) { URI("memory://foobar") }

      it { is_expected.to eq(Specwrk::Store::MemoryAdapter) }
    end

    context "file" do
      let(:uri) { URI("file://foo/bar") }

      it { is_expected.to eq(Specwrk::Store::FileAdapter) }
    end

    context "redis" do
      let(:uri) { URI("redis://foobar") }

      before do
        stub_const("Specwrk::Store::RedisAdapter", Class.new)
      end

      it { is_expected.to eq(Specwrk::Store::RedisAdapter) }
    end

    context "rediss" do
      let(:uri) { URI("rediss://foobar") }

      before do
        stub_const("Specwrk::Store::RedisAdapter", Class.new)
      end

      it { is_expected.to eq(Specwrk::Store::RedisAdapter) }
    end
  end

  describe "instance methods" do
    let(:uri_string) { "file://#{Dir.tmpdir}" }
    let(:scope) { SecureRandom.uuid }

    let(:instance) { described_class.new(uri_string, scope) }

    before { instance.clear }

    describe "#[]" do
      subject { instance[:foo] }

      before do
        instance[:foo] = "bar"
      end

      it { is_expected.to eq("bar") }
    end

    describe "#[]=" do
      subject { instance[:foo] = 42 }

      it { expect { subject }.to change { instance[:foo] }.from(nil).to(42) }
    end

    describe "#keys" do
      subject { instance.keys }

      before do
        instance["a"] = 1
        instance["____secret"] = 2
        instance["b"] = 3
      end

      it { is_expected.to eq(%w[a b]) }
    end

    describe "#length" do
      subject { instance.length }

      before { instance.merge!(x: 1, y: 2) }

      it { is_expected.to eq(2) }
    end

    describe "#delete" do
      subject { instance.delete("key") }

      before { instance["key"] = "val" }

      it { expect { subject }.to change(instance, :keys).from(["key"]).to([]) }
    end

    describe "#merge!" do
      subject { instance.merge!(:alpha => 1, "beta" => 2) }

      before { instance["alpha"] = 0 }

      it { expect { subject }.to change(instance, :inspect).from(alpha: 0).to(alpha: 1, beta: 2) }
    end

    describe "#clear" do
      subject { instance.clear }

      before { instance.merge!("foo" => 1, "baz" => 2) }

      it { expect { subject }.to change(instance, :keys).from(match_array(["foo", "baz"])).to([]) }
    end

    describe "#inspect" do
      subject { instance.inspect }

      before do
        instance.merge!("foo" => 1, "baz" => 2)
      end

      it { is_expected.to eq(foo: 1, baz: 2) }
    end
  end
end
