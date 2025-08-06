# frozen_string_literal: true

require "tempfile"
require "securerandom"

require "specwrk/store"

RSpec.describe Specwrk::Store do
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

  describe "#merge!" do
    subject { instance.merge!(:alpha => 1, "beta" => 2) }

    before { instance["alpha"] = 0 }

    it { expect { subject }.to change(instance, :inspect).from(alpha: 0).to(alpha: 1, beta: 2) }
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
RSpec.describe Specwrk::ProcessingStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }

  before { instance.clear }

  describe "#expired" do
    subject { instance.expired }

    before do
      allow(Time).to receive(:now).and_return(Time.at(1_000_000))

      instance.merge!(
        "past_item" => {completion_threshold: 500},
        "exact_now_item" => {completion_threshold: 1_000_000},
        "future_item" => {completion_threshold: 1_500_000},
        "no_threshold" => {some_other_key: "foo"}
      )
    end

    it { is_expected.to have_key("past_item") }
    it { is_expected.not_to have_key("no_threshold") }
  end
end

RSpec.describe Specwrk::CompletedStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }

  before { instance.clear }

  describe "#dump" do
    subject { instance.dump }

    let(:example_1) do
      {
        id: "./spec/specwrk/worker/progress_formatter_spec.rb[1:1:1]",
        status: "passed",
        file_path: "./spec/specwrk/worker/progress_formatter_spec.rb",
        started_at: "2025-06-26T09:20:58.444542-06:00",
        finished_at: "2025-06-26T09:20:58.444706-06:00",
        run_time: 0.000164
      }
    end
    let(:example_2) do
      {
        id: "./spec/specwrk/worker/progress_formatter_spec.rb[1:1:2]",
        status: "failed",
        file_path: "./spec/specwrk/worker/progress_formatter_spec.rb",
        started_at: "2025-06-26T09:20:58.444542-06:00",
        finished_at: "2025-06-26T09:20:58.444706-06:00",
        run_time: 0.000164
      }
    end
    let(:example_3) do
      {
        id: "./spec/specwrk/web/endpoints_spec.rb[1:4:3:1]",
        status: "pending",
        file_path: "./spec/specwrk/web/endpoints_spec.rb",
        started_at: "2025-06-26T09:20:58.448618-06:00",
        finished_at: "2025-06-26T09:20:58.456148-06:00",
        run_time: 0.00753
      }
    end
    let(:example_4) do
      {
        id: "./spec/specwrk_spec.rb[1:1]",
        status: "passed",
        file_path: "./spec/specwrk_spec.rb",
        started_at: "2025-06-26T09:20:58.434063-06:00",
        finished_at: "2025-06-26T09:20:58.434257-06:00",
        run_time: 0.000194
      }
    end

    before do
      instance.merge!(a: example_1, b: example_2, c: example_3, d: example_4)
    end

    it "dumps the data to a JSON file" do
      expect(subject).to eq({
        examples: {
          example_1[:id] => example_1,
          example_2[:id] => example_2,
          example_3[:id] => example_3,
          example_4[:id] => example_4
        },
        file_totals: {
          "./spec/specwrk/web/endpoints_spec.rb" => 0.00753,
          "./spec/specwrk/worker/progress_formatter_spec.rb" => 0.000328,
          "./spec/specwrk_spec.rb" => 0.000194
        },
        meta: {
          average_run_time: 0.002013,
          first_started_at: "2025-06-26T09:20:58.434063-06:00",
          last_finished_at: "2025-06-26T09:20:58.456148-06:00",
          passes: 2,
          failures: 1,
          pending: 1,
          total_run_time: 0.008052
        }
      })
    end
  end
end
