# frozen_string_literal: true

require "specwrk/web/endpoints/complete_and_pop"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::CompleteAndPop do
  include_context "worker endpoint"

  let(:request_method) { "POST" }

  let(:body) {
    JSON.generate([
      {id: "a.rb:1", file_path: "a.rb", run_time: 0.1, started_at: Time.now.iso8601, finished_at: Time.now.iso8601, status: "passed"},
      {id: "a.rb:3", file_path: "a.rb", run_time: 0.1, started_at: Time.now.iso8601, finished_at: Time.now.iso8601, status: "passed"},
      {id: "a.rb:4", file_path: "a.rb", run_time: 0.1, started_at: Time.now.iso8601, finished_at: Time.now.iso8601, status: "pending"},
      {id: "a.rb:5", file_path: "a.rb", run_time: 0.1, started_at: Time.now.iso8601, finished_at: Time.now.iso8601, status: "failed"}
    ])
  }

  context "completes examples" do
    let(:existing_processing_data) do
      {
        "a.rb:1": {id: "a.rb:1", file_path: "a.rb", expected_run_time: 0.1},
        "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1},
        "a.rb:4": {id: "a.rb:4", file_path: "a.rb", expected_run_time: 0.1},
        "a.rb:5": {id: "a.rb:5", file_path: "a.rb", expected_run_time: 0.1}
      }
    end

    it { is_expected.to eq([404, {"content-type" => "text/plain", "x-specwrk-status" => "1"}, ["This is not the path you're looking for, 'ol chap..."]]) } # 404 since there are no more items in the pending queue
    it { expect { subject }.to change { run_times.reload.length }.from(0).to(4) }
    it { expect { subject }.to change { processing.reload.length }.from(4).to(1) }
    it { expect { subject }.to change { completed.reload.length }.from(0).to(3) }
    it { expect { subject }.to change { worker["passed"] }.from(nil).to(1) }
    it { expect { subject }.to change { worker["failed"] }.from(nil).to(1) }
    it { expect { subject }.to change { worker["pending"] }.from(nil).to(1) }
  end

  context "successfully pops an item off the queue" do
    let(:existing_pending_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "0"}, [JSON.generate([{id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}])]]) }
    it { expect { subject }.to change { pending.reload.length }.from(1).to(0) }
    it { expect { subject }.to change { processing.reload["a.rb:2"] }.from(nil).to({completion_threshold: instance_of(Float), expected_run_time: 0.1, file_path: "a.rb", id: "a.rb:2"}) }
  end

  context "no items in the processing queue, but completed queue has items" do
    let(:existing_completed_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([410, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["That's a good lad. Run along now and go home."]]) }
  end

  context "no items in the pending queue, but something in the processing queue but none are expired" do
    let(:existing_processing_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([404, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["This is not the path you're looking for, 'ol chap..."]]) }
  end

  context "no items in the pending queue, but something in the processing queue it is expired" do
    let(:existing_processing_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1, completion_threshold: (Time.now - 1).to_i}}
    end

    it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "0"}, [JSON.generate([existing_processing_data.values.first])]]) }
    it { expect { subject }.to change { processing["a.rb:2"][:completion_threshold] } }
  end

  context "retries examples" do
    let(:existing_failure_counts_data) { {"a.rb:1" => 1, "a.rb:2" => 5} }

    let(:body) do
      JSON.generate([
        {id: "a.rb:1", file_path: "a.rb", expected_run_time: 0.1, status: "failed"},
        {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1, status: "failed"},
        {id: "a.rb:3", file_path: "a.rb", expected_run_time: 0.1, status: "failed"},
        {id: "a.rb:4", file_path: "a.rb", expected_run_time: 0.1, status: "passed"}
      ])
    end

    let(:existing_processing_data) do
      {
        "a.rb:1": {id: "a.rb:1", file_path: "a.rb", expected_run_time: 0.1},
        "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1},
        "a.rb:3": {id: "a.rb:3", file_path: "a.rb", expected_run_time: 0.1},
        "a.rb:4": {id: "a.rb:4", file_path: "a.rb", expected_run_time: 0.1}
      }
    end

    let(:response_body) do
      JSON.generate([
        {id: "a.rb:1", file_path: "a.rb", expected_run_time: 0.1, status: "failed"},
        {id: "a.rb:3", file_path: "a.rb", expected_run_time: 0.1, status: "failed"}
      ])
    end

    before { pending.max_retries = 5 }

    it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "1"}, [response_body]]) }
    it { expect { subject }.to change { processing.reload.length }.from(4).to(2) }
    it { expect { subject }.to change { failure_counts.reload.to_h.values }.from(match_array([1, 5])).to(match_array([2, 5, 1])) }
  end
end
