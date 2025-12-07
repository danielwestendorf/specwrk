# frozen_string_literal: true

require "securerandom"
require "tmpdir"

require "specwrk/store/pending_store"
require "specwrk/store/bucket_store"

RSpec.describe Specwrk::PendingStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }

  before { instance.clear }

  def bucket_for(id)
    Specwrk::BucketStore.new(uri_string, File.join(scope, "buckets", id))
  end

  describe "#run_time_bucket_maximum=" do
    subject { instance.run_time_bucket_maximum = 3 }

    it { expect { subject }.to change(instance, :run_time_bucket_maximum).from(nil).to(3) }
  end

  describe "#run_time_bucket_maximum" do
    subject { instance.run_time_bucket_maximum }

    before { instance[described_class::RUN_TIME_BUCKET_MAXIMUM_KEY] = 4 }

    it { is_expected.to eq(4) }
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
    context "grouping by timings" do
      before do
        stub_const("ENV", ENV.to_h.merge("SPECWRK_SRV_GROUP_BY" => "timings"))
        instance.run_time_bucket_maximum = 2.5
      end

      it "creates buckets that respect the timing threshold" do
        instance.merge!({
          "a.rb:2": {id: "a.rb:2", expected_run_time: 1.2},
          "a.rb:3": {id: "a.rb:3", expected_run_time: 1.3},
          "a.rb:4": {id: "a.rb:4", expected_run_time: 1.4}
        })

        first_bucket_id = instance.shift_bucket
        second_bucket_id = instance.shift_bucket

        expect(first_bucket_id).not_to eq(second_bucket_id)
        expect(bucket_for(first_bucket_id).examples).to eq([
          {id: "a.rb:2", expected_run_time: 1.2},
          {id: "a.rb:3", expected_run_time: 1.3}
        ])
        expect(bucket_for(second_bucket_id).examples).to eq([
          {id: "a.rb:4", expected_run_time: 1.4}
        ])
        expect(instance.shift_bucket).to be_nil
      end
    end

    context "grouping by file" do
      before do
        stub_const("ENV", ENV.to_h.merge("SPECWRK_SRV_GROUP_BY" => "file"))
      end

      it "creates buckets grouped by file path" do
        instance.merge!({
          "a.rb:4": {id: "a.rb:4", expected_run_time: 1.2, file_path: "a.rb"},
          "a.rb:5": {id: "a.rb:5", expected_run_time: 1.3, file_path: "a.rb"},
          "b.rb:1": {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
        })

        first_bucket_id = instance.shift_bucket
        second_bucket_id = instance.shift_bucket

        expect(bucket_for(first_bucket_id).examples).to eq([
          {id: "a.rb:4", expected_run_time: 1.2, file_path: "a.rb"},
          {id: "a.rb:5", expected_run_time: 1.3, file_path: "a.rb"}
        ])
        expect(bucket_for(second_bucket_id).examples).to eq([
          {id: "b.rb:1", expected_run_time: 1.4, file_path: "b.rb"}
        ])
        expect(instance.shift_bucket).to be_nil
      end
    end
  end

  describe "#shift_bucket" do
    it "returns nil when no buckets remain" do
      expect(instance.shift_bucket).to be_nil
    end
  end

  describe "#push_examples" do
    it "adds a new bucket and returns its data later" do
      instance.push_examples([{id: "a.rb:1", file_path: "a.rb"}])

      bucket_id = instance.shift_bucket
      expect(bucket_id).to be_a(String)
      expect(bucket_for(bucket_id).examples).to eq([{id: "a.rb:1", file_path: "a.rb"}])
    end
  end

  describe "#clear" do
    it "removes stored buckets" do
      instance.push_examples([{id: "a.rb:1", file_path: "a.rb"}])
      bucket_id = instance.shift_bucket
      bucket = bucket_for(bucket_id)

      expect(bucket.examples).to eq([{id: "a.rb:1", file_path: "a.rb"}])

      instance.bucket_ids = [bucket_id]
      instance.clear

      expect(bucket.reload.examples).to eq([])
    end
  end

  describe "#bucket_store_for / #delete_bucket" do
    it "returns a bucket store scoped to the pending store and can delete it" do
      instance.push_examples([{id: "a.rb:1", file_path: "a.rb"}])
      bucket_id = instance.shift_bucket

      bucket = instance.bucket_store_for(bucket_id)
      expect(bucket.examples).to eq([{id: "a.rb:1", file_path: "a.rb"}])

      instance.delete_bucket(bucket_id)
      expect(bucket.reload.examples).to eq([])
    end
  end
end
