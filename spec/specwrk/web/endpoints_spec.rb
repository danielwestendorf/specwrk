# frozen_string_literal: true

require "rack"
require "tmpdir"
require "pathname"

require "specwrk/store"
require "specwrk/web"
require "specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints do
  subject { response }

  let(:request) { Rack::Request.new(env) }
  let(:request_method) { "GET" }
  let(:body) { "" }
  let(:response) { instance.response }
  let(:instance) { described_class.new(request) }
  let(:ok) { [200, {"content-type" => "text/plain", "x-specwrk-status" => worker_status.to_s}, ["OK, 'ol chap"]] }
  let(:worker_status) { 1 }

  let(:env) do
    {
      "CONTENT_TYPE" => "application/json",
      "REQUEST_METHOD" => request_method,
      "rack.input" => StringIO.new(body),
      "HTTP_X_SPECWRK_RUN" => run_id,
      "HTTP_X_SPECWRK_ID" => worker_id
    }
  end

  describe "worker endpoints" do
    let(:metadata) { Specwrk::Store.new datastore_uri, "metadata" }
    let(:run_times) { Specwrk::Store.new base_uri, "run_times" }
    let(:pending) { Specwrk::PendingStore.new datastore_uri, "pending" }
    let(:processing) { Specwrk::Store.new datastore_uri, "processing" }
    let(:completed) { Specwrk::CompletedStore.new datastore_uri, "completed" }
    let(:worker) { Specwrk::PendingStore.new datastore_uri, File.join("workers", worker_id.to_s) }
    let(:failure_counts) { Specwrk::Store.new datastore_uri, "failure_counts" }

    let(:existing_run_times_data) { {} }
    let(:existing_pending_data) { {} }
    let(:existing_processing_data) { {} }
    let(:existing_completed_data) { {} }
    let(:existing_worker_data) { {} }
    let(:existing_failure_counts_data) { {} }

    let(:run_id) { "main" }
    let(:worker_id) { :"foobar-0" }
    let(:datastore_uri) { "file://#{datastore_path}" }
    let(:datastore_path) { File.join(base_path, run_id) }
    let(:base_uri) { "file://#{base_path}" }
    let(:base_path) { File.join(Dir.tmpdir, SecureRandom.uuid) }
    let(:env_vars) { {"SPECWRK_OUT" => base_path, "SPECWRK_SRV_STORE_URI" => base_uri} }

    before do
      stub_const("ENV", env_vars)

      metadata.clear
      run_times.tap(&:clear).merge!(existing_run_times_data)
      pending.tap(&:clear).merge!(existing_pending_data)
      processing.tap(&:clear).merge!(existing_processing_data)
      completed.tap(&:clear).merge!(existing_completed_data)
      worker.tap(&:clear).merge!(existing_worker_data)
      failure_counts.tap(&:clear).merge!(existing_failure_counts_data)
    end

    describe Specwrk::Web::Endpoints::Base do
      context "sets worker metatdata at first look" do
        let!(:time) { Time.now }

        before { allow(Time).to receive(:now).and_return(time) }

        it { expect { subject }.to change(worker, :inspect).from({}).to(first_seen_at: time.iso8601, last_seen_at: time.iso8601) }
      end

      context "update the worker metadata at subsequent look" do
        let(:existing_worker_data) { {first_seen_at: (Time.now - 100).iso8601, last_seen_at: (Time.now - 100).iso8601} }

        it { expect { subject }.to change(worker, :inspect) }
      end
    end

    describe Specwrk::Web::Endpoints::Heartbeat do
      it { is_expected.to eq(ok) }
    end

    describe Specwrk::Web::Endpoints::Seed do
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

    describe Specwrk::Web::Endpoints::Pop do
      context "successfully pops an item off the queue" do
        let(:existing_pending_data) do
          {"a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}}
        end

        it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "1"}, [JSON.generate([{id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}])]]) }
        it { expect { subject }.to change { pending.reload.length }.from(1).to(0) }
        it { expect { subject }.to change { processing.reload["a.rb:2"] }.from(nil).to({completion_threshold: instance_of(Integer), expected_run_time: 0.1, file_path: "a.rb", id: "a.rb:2"}) }
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

    describe Specwrk::Web::Endpoints::Report do
      let(:existing_worker_data) { {failed: 42} }

      before do
        completed_dbl = instance_double(Specwrk::CompletedStore)

        allow(instance).to receive(:completed)
          .and_return(completed_dbl)

        allow(completed_dbl).to receive(:dump)
          .and_return({foo: "bar"})
      end

      it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "42"}, [JSON.generate(foo: "bar")]]) }
    end

    describe Specwrk::Web::Endpoints::CompleteAndPop do
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
        it { expect { subject }.to change { processing.reload["a.rb:2"] }.from(nil).to({completion_threshold: instance_of(Integer), expected_run_time: 0.1, file_path: "a.rb", id: "a.rb:2"}) }
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
  end

  describe Specwrk::Web::Endpoints::Health do
    let(:request_method) { "HEAD" }
    let(:run_id) { nil }
    let(:worker_id) { nil }

    it { is_expected.to eq([200, {}, []]) }
  end
end
