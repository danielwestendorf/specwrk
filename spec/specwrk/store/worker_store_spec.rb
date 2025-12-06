# frozen_string_literal: true

require "securerandom"

require "specwrk/store/worker_store"

RSpec.describe Specwrk::WorkerStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }
  let!(:time) { Time.now.round(0) }

  before do
    instance.clear
    allow(Time).to receive(:now).and_return(time)
  end

  describe "#first_seen_at=" do
    subject { instance.first_seen_at = time - 100 }

    it { expect { subject }.to change(instance, :first_seen_at).from(nil).to(time - 100) }
  end

  describe "#first_seen_at" do
    subject { instance.first_seen_at }

    before { instance[described_class::FIRST_SEEN_AT_KEY] = 812 }

    it { is_expected.to eq(Time.at(812)) }
  end

  describe "#last_seen_at=" do
    subject { instance.last_seen_at = time - 100 }

    it { expect { subject }.to change(instance, :last_seen_at).from(nil).to(time - 100) }
  end

  describe "#last_seen_at" do
    subject { instance.last_seen_at }

    before { instance[described_class::LAST_SEEN_AT_KEY] = 812 }

    it { is_expected.to eq(Time.at(812)) }
  end
end
