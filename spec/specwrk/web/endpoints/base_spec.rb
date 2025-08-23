# frozen_string_literal: true

require "specwrk/web/endpoints/base"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Base do
  include_context "worker endpoint"

  context "sets worker metadata at first look" do
    let!(:time) { Time.now }

    before { allow(Time).to receive(:now).and_return(time) }

    it do
      expect { response }
        .to change(worker, :inspect)
        .from({})
        .to(first_seen_at: time.iso8601, last_seen_at: time.iso8601)
    end
  end

  context "updates worker metadata on subsequent look" do
    let(:existing_worker_data) do
      {first_seen_at: (Time.now - 100).iso8601, last_seen_at: (Time.now - 100).iso8601}
    end

    it { expect { response }.to change(worker, :inspect) }
  end
end
