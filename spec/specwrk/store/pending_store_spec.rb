# frozen_string_literal: true

require "securerandom"

require "specwrk/store/pending_store"

RSpec.describe Specwrk::PendingStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }

  before { instance.clear }

  describe "#run_time_bucket_maximum=" do
    subject { instance.run_time_bucket_maximum = 3 }

    it { expect { subject }.to change(instance, :run_time_bucket_maximum).from(nil).to(3) }
  end

  describe "#run_time_bucket_maximum" do
    subject { instance.run_time_bucket_maximum }

    before { instance[described_class::RUN_TIME_BUCKET_MAXIMUM_KEY] = 4 }

    it { is_expected.to eq(4) }
  end

  describe "#order=" do
    subject { instance.order = value }

    context "sets order array" do
      let(:value) { [1, 2] }

      it { expect { subject }.to change(instance, :order).from([]).to([1, 2]) }
    end

    context "order set to empty array nils the stored value" do
      let(:value) { [] }

      before { instance[described_class::ORDER_KEY] = [2, 1] }

      it { expect { subject }.to change { instance[described_class::ORDER_KEY] }.from([2, 1]).to(nil) }
    end
  end

  describe "#order" do
    subject { instance.order }

    context "order not set" do
      it { is_expected.to eq([]) }
    end

    context "order set" do
      before { instance[described_class::ORDER_KEY] = [1, 2] }

      it { is_expected.to eq([1, 2]) }
    end
  end

  describe "#max_retries=" do
    subject { instance.max_retries = 3 }

    it { expect { subject }.to change(instance, :max_retries).from(0).to(3) }
  end

  describe "#max_retries" do
    subject { instance.max_retries }

    before { instance[described_class::MAX_RETRIES_KEY] = 4 }

    it { is_expected.to eq(4) }
  end

  describe "#merge!" do
    subject { instance.merge!(:gamma => 3, :alpha => 1, "beta" => 2) }

    before do
      instance["alpha"] = 0
      instance.order = ["alpha", "nonexistant"]
    end

    it { expect { subject }.to change(instance, :inspect).from(alpha: 0).to(alpha: 1, beta: 2, gamma: 3) }
    it { expect { subject }.to change(instance, :order).from(%w[alpha nonexistant]).to(%w[alpha nonexistant gamma beta]) }
  end

  describe "#shift_bucket" do
    before do
      stub_const("ENV", ENV.to_h.merge("SPECWRK_SRV_GROUP_BY" => group_by))
    end

    context "timing grouping" do
      let(:group_by) { "timings" }

      it "adds at least one item to the bucket, even if it exceeds the threshold" do
        expect(instance).to receive(:bucket_by_timings)
          .and_call_original
          .exactly(1)

        instance.run_time_bucket_maximum = 1.99

        instance.merge!({
          "a.rb:2": {id: "a.rb:2", expected_run_time: 1.2},
          "a.rb:3": {id: "a.rb:3", expected_run_time: 1.3}
        })

        expect(instance.shift_bucket).to eq([
          {id: "a.rb:2", expected_run_time: 1.2}
        ])
      end

      it "buckets examples until the threshold will be exceeded" do
        expect(instance).to receive(:bucket_by_timings)
          .and_call_original
          .exactly(3)

        instance.run_time_bucket_maximum = 2.5

        instance.merge!({
          "a.rb:2": {id: "a.rb:2", expected_run_time: 1.2},
          "a.rb:3": {id: "a.rb:3", expected_run_time: 1.3},
          "a.rb:4": {id: "a.rb:4", expected_run_time: 1.4}
        })

        expect(instance.shift_bucket).to eq([
          {id: "a.rb:2", expected_run_time: 1.2},
          {id: "a.rb:3", expected_run_time: 1.3}
        ])

        expect(instance.shift_bucket).to eq([
          {id: "a.rb:4", expected_run_time: 1.4}
        ])

        expect(instance.shift_bucket).to eq([])
      end
    end

    context "file grouping" do
      before do
        instance.merge!({
          "a.rb:4": {id: "a.rb:4", expected_run_time: 1.2, file_path: "a.rb"},
          "a.rb:5": {id: "a.rb:5", expected_run_time: 1.3, file_path: "a.rb"},
          "b.rb:1": {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
        })
      end

      context "because of lack of previous runtimes" do
        let(:group_by) { "foobar" }

        it "buckets by file" do
          expect(instance).to receive(:bucket_by_file)
            .and_call_original
            .exactly(3)

          expect(instance.shift_bucket).to eq([
            {id: "a.rb:4", expected_run_time: 1.2, file_path: "a.rb"},
            {id: "a.rb:5", expected_run_time: 1.3, file_path: "a.rb"}
          ])

          expect(instance.shift_bucket).to eq([
            {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
          ])

          expect(instance.shift_bucket).to eq([])
        end
      end

      context "because of configuration" do
        let(:group_by) { "file" }

        it "buckets by file" do
          expect(instance).to receive(:bucket_by_file)
            .and_call_original
            .exactly(3)

          expect(instance.shift_bucket).to eq([
            {id: "a.rb:4", expected_run_time: 1.2, file_path: "a.rb"},
            {id: "a.rb:5", expected_run_time: 1.3, file_path: "a.rb"}
          ])

          expect(instance.shift_bucket).to eq([
            {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
          ])

          expect(instance.shift_bucket).to eq([])
        end
      end
    end
  end
end
