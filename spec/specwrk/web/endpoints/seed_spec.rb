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
    it { expect { subject }.to change(pending, :inspect).from("b.rb:2": instance_of(Hash)).to("a.rb:1": instance_of(Hash)) }
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

    it { expect { subject }.to change { pending.reload.keys }.from([]).to(%w[a.rb:1 a.rb:2 b.rb:1]) }
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

    it { expect { subject }.to change { pending.reload.keys }.from([]).to(%w[b.rb:3 b.rb:4 a.rb:2 a.rb:1]) }
    it { expect { subject }.to change { pending.reload.run_time_bucket_maximum }.from(nil).to(0.7) }
  end
end
