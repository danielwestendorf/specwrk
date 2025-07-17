# frozen_string_literal: true

require "tempfile"
require "securerandom"

require "specwrk/queue"

RSpec.describe Specwrk::Queue do
  describe "#initialize" do
    context "with a block" do
      subject { instance[:not_set] }

      let(:instance) { described_class.new { |h, key| 1 } }

      it { is_expected.to eq(1) }
    end
  end

  describe "#method_missing" do
    subject { instance.delete(:foo) }

    let(:instance) { described_class.new(foo: "bar") }

    it { is_expected.to eq("bar") }
  end

  describe "#responds_to_missing?" do
    subject { described_class.new.respond_to?(:clear) }

    it { is_expected.to eq(true) }
  end
end

RSpec.describe Specwrk::PendingQueue do
  describe "#previous_run_times" do
    subject { instance.previous_run_times }

    let(:instance) { described_class.new }
    let(:env) { {"SPECWRK_OUT" => Dir.tmpdir} }

    before { stub_const("ENV", env) }

    context "when SPECWRK_OUT is not set" do
      let(:env) { {} }

      it { is_expected.to be_nil }
    end

    context "when previous_run_times_file_path returns no path" do
      before do
        allow(instance).to receive(:previous_run_times_file_path).and_return(nil)
      end

      it { is_expected.to be_nil }
    end

    context "when previous_run_times_file_path returns a non-existent path" do
      let(:fake_path) { "/tmp/does_not_exist.json" }

      before do
        allow(instance).to receive(:previous_run_times_file_path).and_return(fake_path)
      end

      it { is_expected.to be_nil }
    end

    context "when the file exists" do
      let(:tmp_file) { File.join(Dir.tmpdir, "#{SecureRandom.uuid}.json") }
      let(:data) { {foo: "bar", count: 5} }
      let(:data_string) { data.to_json }

      before do
        allow(instance).to receive(:previous_run_times_file_path).and_return(tmp_file)
        File.write(tmp_file, data_string)
      end

      after { FileUtils.rm_f(tmp_file) }

      context "handles json parsing errors" do
        let(:data_string) { "fff" }

        it "warns" do
          expect(instance).to receive(:warn)
            .with("#<JSON::ParserError: unexpected token 'fff' at line 1 column 1> in file #{tmp_file}")

          expect { subject }.not_to raise_error
        end
      end

      context "reads and parses the JSON into a symbolized hash" do
        it { is_expected.to eq(data) }
      end

      context "memoizes the result" do
        it "only parses once" do
          expect(File).to receive(:open).once.and_call_original
          2.times { instance.previous_run_times }
        end
      end
    end
  end

  describe "#merge_with_previous_run_times!" do
    subject { instance.merge_with_previous_run_times!(h2).keys }

    let(:instance) { described_class.new }

    let(:h2) do
      {
        "a.rb:1": {id: "a.rb:1", file_path: "a.rb"},
        "b.rb:1": {id: "b.rb:1", file_path: "b.rb"},
        "d.rb:1": {id: "d.rb:1", file_path: "d.rb"},
        "c.rb:1": {id: "c.rb:1", file_path: "c.rb"}
      }
    end

    let(:previous_run_times) do
      {
        meta: {average_run_time: 1.0},
        examples: {
          "a.rb:1": {run_time: 0.1},
          "b.rb:1": {run_time: 1.0},
          "c.rb:1": {run_time: 2.0}
        }
      }
    end

    before { allow(instance).to receive(:previous_run_times).and_return(previous_run_times) }

    # d.rb:1 is first because its run time is unknown, so we assume it is slowe
    # c.rb:1 is second because its run time is the highest known run time
    # b.rb:1 is third because its run time is faster than c.rb:1 and slower than a.rb:1
    # a.rb:1 is fourth because its run time is fastest
    it { is_expected.to eq(%w[d.rb:1 c.rb:1 b.rb:1 a.rb:1]) }
  end

  describe "#shift_bucket" do
    let(:instance) { described_class.new }

    before do
      stub_const("ENV", ENV.to_h.merge("SPECWRK_SRV_GROUP_BY" => group_by))

      allow(instance).to receive(:previous_run_times)
        .and_return(previous_run_times)
    end

    context "timing grouping" do
      let(:group_by) { "timings" }
      let(:previous_run_times) { true }

      it "adds at least one item to the bucket, even if it exceeds the threshold" do
        allow(instance).to receive(:run_time_bucket_threshold)
          .and_return(0.1)

        expect(instance).to receive(:bucket_by_timings)
          .and_call_original
          .exactly(1)

        instance.merge!({
          "a.rb:2": {id: "a.rb:2", expected_run_time: 1.2},
          "a.rb:3": {id: "a.rb:3", expected_run_time: 1.3}
        })

        expect(instance.shift_bucket).to eq([
          {id: "a.rb:2", expected_run_time: 1.2}
        ])
      end

      it "buckets examples until the threshold will be exceeded" do
        allow(instance).to receive(:run_time_bucket_threshold)
          .and_return(2.6)

        expect(instance).to receive(:bucket_by_timings)
          .and_call_original
          .exactly(3)

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
          "a.rb:2": {id: "a.rb:2", expected_run_time: 1.2, file_path: "a.rb"},
          "a.rb:3": {id: "a.rb:3", expected_run_time: 1.3, file_path: "a.rb"},
          "b.rb:1": {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
        })
      end

      context "because of lack of previous runtimes" do
        let(:group_by) { "foobar" }
        let(:previous_run_times) { false }

        it "buckets by file" do
          expect(instance).to receive(:bucket_by_file)
            .and_call_original
            .exactly(3)

          expect(instance.shift_bucket).to eq([
            {id: "a.rb:2", expected_run_time: 1.2, file_path: "a.rb"},
            {id: "a.rb:3", expected_run_time: 1.3, file_path: "a.rb"}
          ])

          expect(instance.shift_bucket).to eq([
            {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
          ])

          expect(instance.shift_bucket).to eq([])
        end
      end

      context "because of configuration" do
        let(:group_by) { "file" }
        let(:previous_run_times) { true }

        it "buckets by file" do
          expect(instance).to receive(:bucket_by_file)
            .and_call_original
            .exactly(3)

          expect(instance.shift_bucket).to eq([
            {id: "a.rb:2", expected_run_time: 1.2, file_path: "a.rb"},
            {id: "a.rb:3", expected_run_time: 1.3, file_path: "a.rb"}
          ])

          expect(instance.shift_bucket).to eq([
            {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
          ])

          expect(instance.shift_bucket).to eq([])
        end
      end
    end
  end

  describe "#run_time_bucket_threshold" do
    subject { instance.run_time_bucket_threshold }

    let(:instance) { described_class.new }

    let(:previous_run_times) do
      {
        meta: {average_run_time: 42.0}
      }
    end

    before { allow(instance).to receive(:previous_run_times).and_return(previous_run_times) }

    context "with previous_run_times" do
      it { is_expected.to eq(42) }
    end

    context "without previous_run_times" do
      let(:previous_run_times) { nil }

      it { is_expected.to eq(1) }
    end
  end
end

RSpec.describe Specwrk::CompletedQueue do
  describe "#dump_and_write" do
    subject { JSON.parse(File.read(path), symbolize_names: true) }

    let(:instance) { described_class.new }
    let(:path) { File.join(Dir.tmpdir, "#{SecureRandom.uuid}.json") }

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
      instance.dump_and_write(path)
    end

    after { FileUtils.rm_f(path) }

    it "dumps the data to a JSON file" do
      expect(subject).to eq({
        examples: {
          example_1[:id].to_sym => example_1,
          example_2[:id].to_sym => example_2,
          example_3[:id].to_sym => example_3,
          example_4[:id].to_sym => example_4
        },
        file_totals: {
          "./spec/specwrk/web/endpoints_spec.rb": 0.00753,
          "./spec/specwrk/worker/progress_formatter_spec.rb": 0.000328,
          "./spec/specwrk_spec.rb": 0.000194
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
