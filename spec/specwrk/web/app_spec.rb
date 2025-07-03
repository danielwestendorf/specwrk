# frozen_string_literal: true

require "tempfile"

require "specwrk/web/app"

RSpec.describe Specwrk::Web::App do
  describe ".run!" do
    subject { described_class.run! }

    let(:server_opts) do
      {
        Port: ENV.fetch("SPECWRK_SRV_PORT", "5138").to_i,
        Host: "127.0.0.1",
        Logger: kind_of(WEBrick::Log),
        AccessLog: [],
        KeepAliveTimeout: 300
      }
    end

    let(:handler) do
      # Rack v3
      double("handler").tap do |dbl|
        stub_const("Rackup::Handler", Module.new)
        Rackup::Handler.const_set(:WEBrick, dbl)
      end
    end

    context "handler" do
      context "rack v3" do
        it "runs the handler" do
          expect(handler).to receive(:run)
            .with(instance_of(Rack::Builder), **server_opts)
            .and_return("true")

          described_class.run!
        end
      end

      context "rack v2" do
        let(:handler) do
          double("handler").tap do |dbl|
            hide_const("Rackup::Handler")
            stub_const("Rack::Handler", class_double("Rack::Handler", get: dbl))
          end
        end

        it "runs the handler" do
          expect(handler).to receive(:run)
            .with(instance_of(Rack::Builder), **server_opts)
            .and_return("true")

          described_class.run!
        end
      end
    end

    context "logging" do
      it "redirects STDOUT when SPECWRK_SRV_LOG set" do
        stub_const("ENV", {"SPECWRK_SRV_LOG" => "foobar.log"})

        expect($stdout).to receive(:reopen)
          .with("foobar.log", "w")
        expect(handler).to receive(:run)
          .with(instance_of(Rack::Builder), **server_opts)
          .and_return("true")

        described_class.run!
      end

      it "does not redirect STDOUT when SPECWRK_SRV_LOG set" do
        stub_const("ENV", {})

        expect($stdout).not_to receive(:reopen)

        expect(handler).to receive(:run)
          .with(instance_of(Rack::Builder), **server_opts)
          .and_return("true")

        described_class.run!
      end
    end
  end

  describe "#call" do
    subject { mock_request.request(http_method, path).status }

    let(:mock_request) { Rack::MockRequest.new(described_class.new) }

    def stub_endpoint(klass, status_code)
      instance_double(klass, response: [status_code, {}, []]).tap do |dbl|
        allow(klass).to receive(:new).with(instance_of(Rack::Request)).and_return(dbl)
      end
    end

    context "GET /heartbeat" do
      let(:http_method) { "GET" }
      let(:path) { "/heartbeat" }

      before { stub_endpoint(Specwrk::Web::Endpoints::Heartbeat, 100) }

      it { is_expected.to eq 100 }
    end

    context "POST /pop" do
      let(:http_method) { "POST" }
      let(:path) { "/pop" }

      before { stub_endpoint(Specwrk::Web::Endpoints::Pop, 101) }

      it { is_expected.to eq 101 }
    end

    context "POST /complete" do
      let(:http_method) { "POST" }
      let(:path) { "/complete" }

      before { stub_endpoint(Specwrk::Web::Endpoints::Complete, 102) }

      it { is_expected.to eq 102 }
    end

    context "POST /seed" do
      let(:http_method) { "POST" }
      let(:path) { "/seed" }

      before { stub_endpoint(Specwrk::Web::Endpoints::Seed, 103) }

      it { is_expected.to eq 103 }
    end

    context "unmatched route" do
      let(:http_method) { "GET" }
      let(:path) { "/bogus" }

      before { stub_endpoint(Specwrk::Web::Endpoints::NotFound, 104) }

      it { is_expected.to eq 104 }
    end
  end
end
