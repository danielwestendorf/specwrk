# frozen_string_literal: true

require "rack"
require "tmpdir"
require "pathname"

require "specwrk/web"
require "specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints do
  subject { response }

  def datastore
    JSON.parse(File.read(datastore_path), symbolize_names: true)
  rescue Errno::ENOENT
    Hash.new { |h, k| h[k] = {} }
  end

  def pending_queue
    datastore[:pending] || {}
  end

  def processing_queue
    datastore[:processing] || {}
  end

  def completed_queue
    datastore[:completed] || {}
  end

  def worker
    datastore.dig(:workers, worker_id)
  end

  let(:request) { Rack::Request.new(env) }
  let(:env) { {"rack.input" => StringIO.new(body), "HTTP_X_SPECWRK_RUN" => run_id, "HTTP_X_SPECWRK_ID" => worker_id} }
  let(:body) { "" }
  let(:run_id) { "main" }
  let(:worker_id) { :"foobar-0" }
  let(:response) { instance.response }
  let(:instance) { described_class.new(request) }
  let(:ok) { [200, {"Content-Type" => "text/plain"}, ["OK, 'ol chap"]] }

  let(:datastore_path) { File.join(base_path, run_id, "queues.json").to_s.tap { |path| FileUtils.mkdir_p(Pathname.new(path).dirname) } }
  let(:env_vars) { {"SPECWRK_OUT" => base_path} }
  let(:existing_data) { nil }
  let(:base_path) { File.join(Dir.tmpdir, Process.pid.to_s).to_s.tap { |path| FileUtils.mkdir_p(path) } }

  before do
    stub_const("ENV", env_vars)
    File.write(datastore_path, existing_data.to_json) if existing_data
  end

  after { FileUtils.rm_f Dir.glob(File.join(base_path, run_id, "*.*")) }

  describe Specwrk::Web::Endpoints::Base do
    context "sets worker metatdata at first look" do
      it { expect { subject }.to change { worker }.from(nil).to(instance_of(Hash)) }
    end

    context "update the worker metadata at subsequent look" do
      let(:existing_data) { {first_seen_at: (Time.now - 100), last_seen_at: (Time.now - 100)} }

      it { expect { subject }.to change { worker } }
    end
  end

  describe Specwrk::Web::Endpoints::Heartbeat do
    it { is_expected.to eq(ok) }
  end

  describe Specwrk::Web::Endpoints::Seed do
    let(:body) { JSON.generate([{id: "a.rb:1", file_path: "a.rb", run_time: 0.1}]) }

    context "SPECWRK_SRV_SINGLE_SEED_PER_RUN and pending_queue already has examples" do
      let(:existing_data) { {pending: {"b.rb:1" => {id: "b.rb:1", file_path: "b.rb", expected_run_time: 0.1}}} }
      let(:env_vars) { {"SPECWRK_OUT" => base_path, "SPECWRK_SRV_SINGLE_SEED_PER_RUN" => "1"} }

      it { is_expected.to eq(ok) }
      it { expect { subject }.not_to change(pending_queue, :length) }
    end

    context "SPECWRK_SRV_SINGLE_SEED_PER_RUN but pending_queue is empty" do
      let(:env_vars) { {"SPECWRK_OUT" => base_path, "SPECWRK_SRV_SINGLE_SEED_PER_RUN" => "1"} }

      it { is_expected.to eq(ok) }
      it { expect { subject }.to change { pending_queue.length }.from(0).to(1) }
    end

    context "examples get merged into pending queue" do
      let(:existing_data) { {pending: {"b.rb:2" => {id: "b.rb:2", file_path: "b.rb", expected_run_time: 0.1}}} }
      let(:env_vars) { {"SPECWRK_OUT" => base_path, "SPECWRK_SRV_SINGLE_SEED_PER_RUN" => nil} }

      it { is_expected.to eq(ok) }
      it { expect { subject }.to change { pending_queue.length }.from(1).to(2) }
    end
  end

  describe Specwrk::Web::Endpoints::Complete do
    let(:report_file_path_pattern) { File.join(base_path, run_id, "*-report.json") }
    let(:body) {
      JSON.generate([
        {id: "a.rb:1", file_path: "a.rb", run_time: 0.1, started_at: Time.now.iso8601, finished_at: Time.now.iso8601},
        {id: "a.rb:3", file_path: "a.rb", run_time: 0.1, started_at: Time.now.iso8601, finished_at: Time.now.iso8601}
      ])
    }

    let(:existing_data) do
      {
        processing: {
          "a.rb:1": {id: "a.rb:1", file_path: "a.rb", expected_run_time: 0.1},
          "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}
        }
      }
    end

    it { is_expected.to eq(ok) }
    it { expect { subject }.to change { processing_queue.length }.from(2).to(1) }
    it { expect { subject }.to change { completed_queue.length }.from(0).to(1) }

    context "output file requested" do
      context "pending queue isn't empty" do
        let(:existing_data) do
          {
            pending: {
              "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}
            }
          }
        end

        it "doesn't try to dump the completed queue" do
          expect { subject }.not_to change(Dir.glob(report_file_path_pattern), :length)
        end
      end

      context "processing queue isn't empty" do
        let(:existing_data) do
          {
            processing: {
              "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}
            }
          }
        end

        it "doesn't try to dump the completed queue" do
          expect { subject }.not_to change(Dir.glob(report_file_path_pattern), :length)
        end
      end

      context "completed queue is empty" do
        let(:body) { JSON.generate([]) }
        let(:existing_data) { nil }

        it "doesn't try to dump the completed queue" do
          expect { subject }.not_to change(Dir.glob(report_file_path_pattern), :length)
        end
      end

      context "pending and processing queues are empty" do
        let(:existing_data) do
          {
            processing: {
              "a.rb:1": {id: "a.rb:1", file_path: "a.rb", expected_run_time: 0.1}
            }
          }
        end

        it "does dump the completed queue" do
          expect { subject }.to change { Dir.glob(report_file_path_pattern).length }.from(0).to(1)
        end
      end
    end
  end

  describe Specwrk::Web::Endpoints::Pop do
    context "successfully pops an item off the queue" do
      let(:existing_data) do
        {
          pending: {
            "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}
          }
        }
      end

      it { is_expected.to eq([200, {"Content-Type" => "application/json"}, [JSON.generate([{id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}])]]) }
      it { expect { subject }.to change { pending_queue.length }.from(1).to(0) }
      it { expect { subject }.to change { processing_queue.length }.from(0).to(1) }
    end

    context "no items in any queue" do
      it { is_expected.to eq([204, {"Content-Type" => "text/plain"}, ["Waiting for sample to be seeded."]]) }
    end

    context "no items in the processing queue, but completed queue has items" do
      let(:existing_data) do
        {
          pending: {},
          processing: {},
          completed: {
            "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}
          }
        }
      end

      it { is_expected.to eq([410, {"Content-Type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]) }
    end

    context "no items in the pending queue, but something in the processing queue" do
      let(:existing_data) do
        {
          processing: {
            "a.rb:2": {id: "a.rb:2", file_path: "a.rb", expected_run_time: 0.1}
          }
        }
      end

      it { is_expected.to eq([404, {"Content-Type" => "text/plain"}, ["This is not the path you're looking for, 'ol chap..."]]) }
    end
  end

  describe Specwrk::Web::Endpoints::Report do
    let(:most_recent_run_report_file) { File.join(base_path, "#{SecureRandom.uuid}.json").to_s }

    before do
      allow(instance).to receive(:most_recent_run_report_file)
        .and_return(most_recent_run_report_file)
    end

    context "run report file does not exist" do
      it { is_expected.to eq([404, {"Content-Type" => "text/plain"}, ["Unable to report on run #{run_id}; no file matching *-report-main.json"]]) }
    end

    context "run report file does exist" do
      let(:file_content) { "file_data" }

      around do |ex|
        File.write(most_recent_run_report_file, file_content)

        ex.run

        FileUtils.rm(most_recent_run_report_file)
      end

      it { is_expected.to eq([200, {"Content-Type" => "application/json"}, [file_content]]) }
    end
  end
end
