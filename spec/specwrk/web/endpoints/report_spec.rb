# frozen_string_literal: true

require "specwrk/web/endpoints/report"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Report do
  include_context "worker endpoint"

  let(:existing_worker_data) { {failed: 42} }
  let(:completed_dbl) { instance_double(Specwrk::CompletedStore) }

  before do
    allow(instance).to receive(:completed)
      .and_return(completed_dbl)

    allow(completed_dbl).to receive(:dump)
      .and_return({foo: "bar", meta: {}})
  end

  it { is_expected.to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "42"}, [JSON.generate(foo: "bar", meta: {unexecuted: 0}, flakes: {})]]) }

  context "when the report is not cached" do
    let(:report_data) { {meta: {}, examples: {}} }

    before do
      allow(completed_dbl).to receive(:dump).and_return(report_data)
    end

    it "caches the generated report for subsequent requests" do
      expect(completed_dbl).to receive(:dump).once.and_return(report_data)

      first_response = instance.response
      second_response = described_class.new(request).response

      expect(second_response).to eq(first_response)
      expect(metadata[:report_json]).to eq(first_response.last.first)
    end
  end
end
