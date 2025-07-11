# frozen_string_literal: true

require "specwrk/web/logger"

RSpec.describe Specwrk::Web::Logger do
  subject { instance.call(env) }

  let(:status) { 200 }
  let(:headers) { {"Content-Type" => "text/plain"} }
  let(:body) { ["OK"] }

  let(:app) do
    ->(env) { [status, headers, body] }
  end

  let(:out) { StringIO.new }
  let(:env) { {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/test", "REMOTE_ADDR" => "127.0.0.1"} }
  let(:time) { Time.now }
  let(:ignored_paths) { ["/noise"] }
  let(:instance) { described_class.new(app, out, ignored_paths) }

  before do
    allow(Time).to receive(:now)
      .and_return(time)

    allow(Process).to receive(:clock_gettime)
      .with(Process::CLOCK_MONOTONIC)
      .and_return(1.0, 1.123456)
  end

  context "logs method, path, status and duration in ms to the given output" do
    it { is_expected.to eq([status, headers, body]) }

    it { expect { subject }.to change(out, :string).to("127.0.0.1 [#{time.iso8601(6)}] GET /test → 200 (123.456ms)\n") }
  end

  context "does not log method, path, status and duration in ms to the given output" do
    let(:env) { {"REQUEST_METHOD" => "GET", "PATH_INFO" => "/noise", "REMOTE_ADDR" => "127.0.0.1"} }

    it { is_expected.to eq([status, headers, body]) }
    it { expect { subject }.not_to change(out, :string) }
  end
end
