# frozen_string_literal: true

require "rack"
require "tmpdir"
require "securerandom"

require "specwrk/store"

RSpec.shared_context "endpoint" do
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
end

RSpec.shared_context "worker endpoint" do
  include_context "endpoint"

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
end
