# frozen_string_literal: true

require "specwrk/web/endpoints/health"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Health do
  include_context "endpoint"

  let(:request_method) { "HEAD" }
  let(:run_id) { nil }
  let(:worker_id) { nil }

  it { is_expected.to eq([200, {}, []]) }
end
