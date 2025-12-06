# frozen_string_literal: true

require "specwrk/web/endpoints/seed"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Seed do
  include_context "worker endpoint"

  let(:request_method) { "POST" }
  let(:body) { JSON.generate(max_retries: 42, examples: [{id: "a.rb:1", file_path: "a.rb", run_time: 0.1}]) }

  context "pending store reset with examples and meta data" do
    let(:existing_pending_data) { {"b.rb:2" => {id: "b.rb:2", file_path: "b.rb", expected_run_time: 0.1}} }

    it { is_expected.to eq(ok) }
    it "replaces pending buckets with the seeded examples" do
      original_bucket_ids = pending.bucket_ids.dup

      subject

      expect(pending.reload.length).to eq(1)

      bucket_id = pending.shift_bucket
      expect(bucket_id).to be_a(String)
      expect(original_bucket_ids).not_to include(bucket_id)
      expect(Specwrk::BucketStore.new(datastore_uri, File.join("pending", "buckets", bucket_id)).examples.map { |ex| ex[:id] }).to eq(["a.rb:1"])
    end
    it { expect { subject }.to change { pending.reload.max_retries }.from(0).to(42) }
  end

  context "merged with  sorted by file" do
    let(:body) do
      JSON.generate(examples: [
        {id: "a.rb:1", file_path: "a.rb"},
        {id: "b.rb:1", file_path: "b.rb"},
        {id: "a.rb:2", file_path: "a.rb"}
      ])
    end

    it "creates buckets grouped by file path" do
      subject

      first_bucket_id = pending.shift_bucket
      second_bucket_id = pending.shift_bucket

      expect(Specwrk::BucketStore.new(datastore_uri, File.join("pending", "buckets", first_bucket_id)).examples.map { |ex| ex[:id] }).to eq(%w[a.rb:1 a.rb:2])
      expect(Specwrk::BucketStore.new(datastore_uri, File.join("pending", "buckets", second_bucket_id)).examples.map { |ex| ex[:id] }).to eq(%w[b.rb:1])
      expect(pending.shift_bucket).to be_nil
    end
  end

  context "merged with run_time_bucket_maximum sorted by timings" do
    let(:existing_run_times_data) do
      {
        "a.rb:1": 0.2,
        "a.rb:2": 0.3,
        "b.rb:4": 0.8
      }
    end

    let(:body) do
      JSON.generate(examples: [
        {id: "a.rb:1", file_path: "a.rb"},
        {id: "a.rb:2", file_path: "a.rb"},
        {id: "b.rb:3", file_path: "b.rb"},
        {id: "b.rb:4", file_path: "b.rb"}
      ])
    end

    it { expect { subject }.to change { pending.reload.run_time_bucket_maximum }.from(nil).to(0.7) }

    it "creates buckets grouped by expected run time" do
      subject

      first_bucket_id = pending.shift_bucket
      second_bucket_id = pending.shift_bucket
      third_bucket_id = pending.shift_bucket

      expect(Specwrk::BucketStore.new(datastore_uri, File.join("pending", "buckets", first_bucket_id)).examples.map { |ex| ex[:id] }).to eq(%w[b.rb:3])
      expect(Specwrk::BucketStore.new(datastore_uri, File.join("pending", "buckets", second_bucket_id)).examples.map { |ex| ex[:id] }).to eq(%w[b.rb:4])
      expect(Specwrk::BucketStore.new(datastore_uri, File.join("pending", "buckets", third_bucket_id)).examples.map { |ex| ex[:id] }).to eq(%w[a.rb:2 a.rb:1])
      expect(pending.shift_bucket).to be_nil
    end
  end
end
