# frozen_string_literal: true

require "specwrk/web/endpoints/report"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Report do
  include_context "worker endpoint"

  let(:existing_worker_data) { {failed: 42} }

  before do
    completed_dbl = instance_double(Specwrk::CompletedStore)

    allow(instance).to receive(:completed)
      .and_return(completed_dbl)

    allow(completed_dbl).to receive(:dump)
      .and_return({foo: "bar", meta: {}})
  end

  it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "42"}, [JSON.generate(foo: "bar", meta: {unexecuted: 0}, flakes: {})]]) }
end
