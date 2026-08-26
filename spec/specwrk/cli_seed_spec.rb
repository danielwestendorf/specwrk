# frozen_string_literal: true

require "specwrk/cli"
require "specwrk/client"
require "specwrk/list_examples"

RSpec.describe Specwrk::CLI::Seed do
  subject(:call) do
    command.call(
      max_retries: 2,
      dir: ["spec"],
      target_bucket_timing_duration: target_bucket_timing_duration,
      uri: "http://localhost:5138",
      key: "",
      run: "main",
      timeout: "5",
      network_retries: "1"
    )
  end

  let(:command) { described_class.new }
  let(:target_bucket_timing_duration) { "0" }
  let(:examples) { [{id: "spec/a_spec.rb:1", file_path: "spec/a_spec.rb"}] }
  let(:client) { instance_double(Specwrk::Client, seed: true) }

  before do
    stub_const("ENV", ENV.to_h)
    allow(Specwrk::ListExamples).to receive(:new).with(["spec"]).and_return(instance_double(Specwrk::ListExamples, examples: examples))
    allow(Specwrk::Client).to receive(:wait_for_server!)
    allow(Specwrk::Client).to receive(:new).and_return(client)
    allow(command).to receive(:puts)
  end

  it "sends zero when no target is given" do
    expect(client).to receive(:seed).with(examples, 2, target_bucket_timing_duration: 0.0)

    call

    expect(ENV["SPECWRK_TARGET_BUCKET_TIMING_DURATION"]).to eq("0.0")
  end

  context "with a target bucket timing duration" do
    let(:target_bucket_timing_duration) { "12.5" }

    it "sends the duration to the client as a number" do
      expect(client).to receive(:seed).with(examples, 2, target_bucket_timing_duration: 12.5)

      call
    end
  end
end
