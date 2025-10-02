# frozen_string_literal: true

require "specwrk/web/endpoints/base"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Base do
  include_context "worker endpoint"

  context "sets worker metadata at first look" do
    let!(:time) { Time.now.round(0) - 100 }

    before { allow(Time).to receive(:now).and_return(time) }

    it do
      expect { response }
        .to change { worker.reload.first_seen_at }
        .from(nil)
        .to(time)
    end

    it do
      expect { response }
        .to change { worker.reload.last_seen_at }
        .from(nil)
        .to(time)
    end
  end

  context "updates worker metadata on subsequent look" do
    let(:existing_worker_data) do
      {Specwrk::WorkerStore::FIRST_SEEN_AT_KEY => (Time.now - 100).to_i, Specwrk::WorkerStore::LAST_SEEN_AT_KEY => (Time.now - 100).to_i}
    end

    it { expect { response }.not_to change { worker.reload.first_seen_at } }
    it { expect { response }.to change { worker.reload.last_seen_at } }
  end
end
