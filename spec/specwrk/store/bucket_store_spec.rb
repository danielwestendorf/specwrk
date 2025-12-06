# frozen_string_literal: true

require "securerandom"
require "tmpdir"

require "specwrk/store/bucket_store"

RSpec.describe Specwrk::BucketStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }

  before { instance.clear }

  describe "#examples=" do
    subject { instance.examples = value }

    context "sets examples array" do
      let(:value) { [1, 2] }

      it { expect { subject }.to change(instance, :examples).from([]).to([1, 2]) }
    end

    context "examples set to empty array nils the stored value" do
      let(:value) { [] }

      before { instance[described_class::EXAMPLES_KEY] = [2, 1] }

      it { expect { subject }.to change { instance[described_class::EXAMPLES_KEY] }.from([2, 1]).to(nil) }
    end
  end

  describe "#examples" do
    subject { instance.examples }

    context "examples not set" do
      it { is_expected.to eq([]) }
    end

    context "examples set" do
      before { instance[described_class::EXAMPLES_KEY] = [1, 2] }

      it { is_expected.to eq([1, 2]) }
    end
  end

  describe "#clear" do
    before { instance.examples = ["foo"] }

    it "resets cached examples" do
      expect(instance.examples).to eq(["foo"])

      instance.clear

      instance[described_class::EXAMPLES_KEY] = ["bar"]

      expect(instance.examples).to eq(["bar"])
    end
  end

  describe "#reload" do
    before do
      instance.examples = ["foo"]
      instance.examples
    end

    it "refreshes the cached examples" do
      instance[described_class::EXAMPLES_KEY] = ["bar"]

      expect(instance.reload.examples).to eq(["bar"])
    end
  end
end
