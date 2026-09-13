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

  context "when the store lock is unavailable" do
    let(:endpoint_class) do
      Class.new(described_class) do
        def with_response
          with_lock { ok }
        end
      end
    end
    let(:instance) { endpoint_class.new(request) }

    before do
      allow(Specwrk::Store).to receive(:with_lock)
        .and_raise(Specwrk::Store::LockUnavailableError)
    end

    it do
      expect(response).to eq([423, {"content-type" => "text/plain"}, ["Locked. Try again later."]])
    end

    context "with a HEAD request" do
      let(:request_method) { "HEAD" }

      it { expect(response).to eq([423, {}, []]) }
    end
  end

  context "when reading request bodies" do
    let(:request_method) { "POST" }
    let(:body) { Zlib.gzip(JSON.generate(foo: "bar")) }
    let(:content_encoding) { "gzip" }
    let(:env) { super().merge("HTTP_CONTENT_ENCODING" => content_encoding) }
    let(:endpoint_class) do
      Class.new(described_class) do
        def with_response
          [200, {"content-type" => "application/json"}, [body]]
        end
      end
    end
    let(:instance) { endpoint_class.new(request) }

    it "decodes a gzip request body" do
      expect(response).to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "1"}, [JSON.generate(foo: "bar")]])
    end

    context "with an identity request body" do
      let(:body) { JSON.generate(foo: "bar") }
      let(:content_encoding) { "identity" }

      it "uses the request body unchanged" do
        expect(response).to eq([200, {"content-type" => "application/json", "x-specwrk-status" => "1"}, [body]])
      end
    end

    context "with malformed gzip" do
      let(:body) { "not gzip" }

      it "returns a bad request response" do
        expect(response).to eq([400, {"content-type" => "text/plain"}, ["Invalid gzip request body"]])
      end
    end

    context "with an unsupported content encoding" do
      let(:body) { "encoded somehow" }
      let(:content_encoding) { "br" }

      it "returns an unsupported media type response" do
        expect(response).to eq([415, {"content-type" => "text/plain"}, ["Unsupported content encoding"]])
      end
    end
  end
end
