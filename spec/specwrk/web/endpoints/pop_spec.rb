# frozen_string_literal: true

require "specwrk/web/endpoints/pop"
require "specwrk/web/endpoints/seed"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Pop do
  include_context "worker endpoint"

  context "successfully pops an item off the queue" do
    let(:existing_pending_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "1"}, [JSON.generate([{id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}])]]) }
    it { expect { subject }.to change { pending.reload.length }.from(1).to(0) }
    it { expect { subject }.to change { processing.reload["a.rb:2"] }.from(nil).to({expected_run_time: 0.1, file_path: "a.rb", id: "a.rb:2", worker_id: "foobar-0", processing_started_at: instance_of(Integer)}) }

    context "when the run has a seed marker" do
      before { pending.max_retries = 0 }

      it "reports zero failures while still delivering work" do
        expect(response[0]).to eq(200)
        expect(response[1]["x-specwrk-status"]).to eq("0")
        expect(JSON.parse(response[2].first).first["id"]).to eq("a.rb:2")
      end
    end
  end

  context "no items in any queue" do
    it { is_expected.to eq([204, {"x-specwrk-status" => "1"}, []]) }
  end

  it "does not signal completion when seeding finishes after the empty queue check" do
    seed_request = Rack::Request.new(env.merge(
      "REQUEST_METHOD" => "POST",
      "rack.input" => StringIO.new(JSON.generate(examples: [{id: "a.rb:1", file_path: "a.rb"}]))
    ))
    allow(instance).to receive(:examples).and_wrap_original do |original|
      original.call.tap do |examples|
        expect(examples).to be_empty
        expect(Specwrk::Web::Endpoints::Seed.new(seed_request).response[0]).to eq(200)
      end
    end

    expect(response[0]).to eq(404)

    next_response = described_class.new(request).response
    expect(next_response[0]).to eq(200)
    expect(JSON.parse(next_response[2].first).first["id"]).to eq("a.rb:1")
  end

  context "no items in a seeded run" do
    before { pending.max_retries = 0 }

    it { is_expected.to eq([404, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["This is not the path you're looking for, 'ol chap..."]]) }

    context "when the worker has recorded failures" do
      let(:existing_worker_data) { {failed: 2} }

      it "preserves the failure status while waiting for completed records" do
        expect(response[0]).to eq(404)
        expect(response[1]["x-specwrk-status"]).to eq("2")
      end
    end

    context "when another worker still has work in progress" do
      let(:existing_processing_data) do
        {"a.rb:1": {id: "a.rb:1", worker_id: other_worker_id}}
      end

      it "waits for the processing work to finish" do
        expect(response[0]).to eq(404)
        expect(response[1]["x-specwrk-status"]).to eq("0")
      end
    end
  end

  context "no items after a seeded run's completed store was reset" do
    let(:seed_request) do
      Rack::Request.new(env.merge(
        "REQUEST_METHOD" => "POST",
        "rack.input" => StringIO.new(JSON.generate(examples: [{id: "a.rb:1", file_path: "a.rb"}]))
      ))
    end

    before do
      Specwrk::Web::Endpoints::Seed.new(seed_request).response
      bucket_id = pending.shift_bucket
      pending.delete_bucket(bucket_id)
      processing.clear
      completed.clear
    end

    it { is_expected.to eq([404, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["This is not the path you're looking for, 'ol chap..."]]) }
  end

  context "no items in the processing queue, no known failed for worker, but completed queue has items" do
    before { pending.max_retries = 0 }

    let(:existing_completed_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([410, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["That's a good lad. Run along now and go home."]]) }
  end

  context "no items in the pending queue, but something in the processing queue but none are expired" do
    before { pending.max_retries = 0 }

    let(:existing_processing_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([404, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["This is not the path you're looking for, 'ol chap..."]]) }

    context "when seeding has not finished" do
      before { pending.delete(Specwrk::PendingStore::MAX_RETRIES_KEY.to_s) }

      it { is_expected.to eq([204, {"x-specwrk-status" => "1"}, []]) }
    end
  end
end
