# frozen_string_literal: true

require "specwrk/web/endpoints/heartbeat"
require "support/specwrk/web/endpoints"

RSpec.describe Specwrk::Web::Endpoints::Heartbeat do
  include_context "worker endpoint"

  it { expect(response).to eq(ok) }
end
