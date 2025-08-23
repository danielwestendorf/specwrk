# frozen_string_literal: true

require "specwrk/web/endpoints/pop"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Pop do
  include_context "worker endpoint"

  context "successfully pops an item off the queue" do
    let(:existing_pending_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "1"}, [JSON.generate([{id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}])]]) }
    it { expect { subject }.to change { pending.reload.length }.from(1).to(0) }
    it { expect { subject }.to change { processing.reload["a.rb:2"] }.from(nil).to({completion_threshold: instance_of(Float), expected_run_time: 0.1, file_path: "a.rb", id: "a.rb:2"}) }
  end

  context "no items in any queue" do
    it { is_expected.to eq([204, {"content-type" => "text/plain", "x-specwrk-status" => "1"}, ["Waiting for sample to be seeded."]]) }
  end

  context "no items in the processing queue, no known failed for worker, but completed queue has items" do
    let(:existing_completed_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([410, {"content-type" => "text/plain", "x-specwrk-status" => "0"}, ["That's a good lad. Run along now and go home."]]) }
  end

  context "no items in the pending queue, but something in the processing queue but none are expired" do
    let(:existing_processing_data) do
      {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
    end

    it { is_expected.to eq([404, {"content-type" => "text/plain", "x-specwrk-status" => "1"}, ["This is not the path you're looking for, 'ol chap..."]]) }
  end
end
