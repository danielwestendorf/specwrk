# frozen_string_literal: true

require "rack"

require "specwrk/web"
require "specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints do
  subject { response }

  let(:request) { Rack::Request.new(env) }
  let(:env) { {"rack.input" => StringIO.new(body), "HTTP_X_SPECWRK_RUN" => run} }
  let(:body) { "" }
  let(:run) { "main" }
  let(:response) { described_class.new(request).response }
  let(:ok) { [200, {"Content-Type" => "text/plain"}, ["OK, 'ol chap"]] }

  let(:pending_queue) { Specwrk::Web::PENDING_QUEUES[run] }
  let(:processing_queue) { Specwrk::Web::PROCESSING_QUEUES[run] }
  let(:completed_queue) { Specwrk::Web::COMPLETED_QUEUES[run] }

  let(:env_vars) { {"SPECWRK_SRV_OUTPUT" => ".non-existant.json"} }

  before { stub_const("ENV", env_vars) }

  around do |ex|
    Specwrk::Web.clear_queues
    ex.run
    Specwrk::Web.clear_queues
  end

  describe Specwrk::Web::Endpoints::Heartbeat do
    let(:env) { {} }

    it { is_expected.to eq(ok) }
  end

  describe Specwrk::Web::Endpoints::Seed do
    let(:body) { JSON.generate([{id: 1, file_path: "a.rb:1", run_time: 0.1}]) }

    context "SPECWRK_SRV_SINGLE_SEED_PER_RUN and pending_queue already has examples" do
      let(:env_vars) { {"SPECWRK_SRV_OUTPUT" => ".non-existant.json", "SPECWRK_SRV_SINGLE_SEED_PER_RUN" => "1"} }

      before { pending_queue.merge!(2 => {id: 2, file_path: "b.rb:1", run_time: 0.1}) }

      it { is_expected.to eq(ok) }
      it { expect { subject }.not_to change(pending_queue, :length) }
    end

    context "SPECWRK_SRV_SINGLE_SEED_PER_RUN and but pending_queue is empty" do
      let(:env_vars) { {"SPECWRK_SRV_OUTPUT" => ".non-existant.json", "SPECWRK_SRV_SINGLE_SEED_PER_RUN" => "1"} }

      it { is_expected.to eq(ok) }
      it { expect { subject }.to change(pending_queue, :length).from(0).to(1) }
    end

    context "examples get merged into pending queue" do
      let(:env_vars) { {"SPECWRK_SRV_OUTPUT" => ".non-existant.json", "SPECWRK_SRV_SINGLE_SEED_PER_RUN" => nil} }

      it { is_expected.to eq(ok) }
      it { expect { subject }.to change(pending_queue, :length).from(0).to(1) }
    end
  end

  describe Specwrk::Web::Endpoints::Complete do
    before do
      processing_queue.merge!(
        1 => {id: 1, file_path: "a.rb:1", run_time: 0.1},
        2 => {id: 2, file_path: "a.rb:2", run_time: 0.1}
      )
    end

    let(:body) { JSON.generate([{id: 1, file_path: "a.rb:1", run_time: 0.1}]) }

    it { is_expected.to eq(ok) }
    it { expect { subject }.to change(processing_queue, :length).from(2).to(1) }
    it { expect { subject }.to change(completed_queue, :length).from(0).to(1) }

    context "output file requested" do
      context "pending queue isn't empty" do
        before do
          processing_queue.delete(2)
          pending_queue.merge!(2 => {id: 2, file_path: "a.rb:1", run_time: 0.1})
        end

        it "doesn't try to dump the completed queue" do
          expect(completed_queue).not_to receive(:dump_and_write)

          subject
        end
      end

      context "processing queue isn't empty" do
        it "doesn't try to dump the completed queue" do
          expect(completed_queue).not_to receive(:dump_and_write)

          subject
        end
      end

      context "pending and processing queues are empty" do
        before do
          processing_queue.delete(2)
        end

        it "does dump the completed queue" do
          expect(completed_queue).to receive(:dump_and_write)

          subject
        end
      end
    end
  end

  describe Specwrk::Web::Endpoints::Pop do
    context "successfully pops an item off the queue" do
      before { pending_queue.merge!(1 => {id: 1, expected_run_time: 0}) }

      it { is_expected.to eq([200, {"Content-Type" => "application/json"}, [JSON.generate([{id: 1, expected_run_time: 0}])]]) }
      it { expect { subject }.to change(pending_queue, :length).from(1).to(0) }
      it { expect { subject }.to change(processing_queue, :length).from(0).to(1) }
    end

    context "no items in any queue" do
      it { is_expected.to eq([204, {"Content-Type" => "text/plain"}, ["Waiting for sample to be seeded."]]) }
    end

    context "no items in the processing queue, but completed queue has items" do
      before { completed_queue.merge!(2 => {id: 2, expected_run_time: 0}) }

      it { is_expected.to eq([410, {"Content-Type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]) }
    end

    context "no items in the pending queue, but something in the processing queue" do
      before { processing_queue.merge!(2 => {id: 2, expected_run_time: 0}) }

      it { is_expected.to eq([404, {"Content-Type" => "text/plain"}, ["This is not the path you're looking for, 'ol chap..."]]) }
    end
  end
end
