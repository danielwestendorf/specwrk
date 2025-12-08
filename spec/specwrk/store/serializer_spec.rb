# frozen_string_literal: true

require "specwrk/store/serializer"

RSpec.describe Specwrk::Store::Serializer do
  around do |example|
    original_env = ENV["SPECWRK_STORE_SERIALIZER"]

    example.run
  ensure
    ENV["SPECWRK_STORE_SERIALIZER"] = original_env
  end

  it "defaults to JSON" do
    ENV.delete("SPECWRK_STORE_SERIALIZER")

    serializer = described_class.resolve
    payload = serializer.dump(foo: "bar")

    expect(serializer).to eq(Specwrk::Store::Serializers::JSON)
    expect(serializer.load(payload)).to eq(foo: "bar")
  end

  it "respects SPECWRK_STORE_SERIALIZER" do
    ENV["SPECWRK_STORE_SERIALIZER"] = "msgpack"

    serializer = described_class.resolve
    payload = serializer.dump(foo: "bar")

    expect(serializer).to eq(Specwrk::Store::Serializers::MessagePack)
    expect(serializer.load(payload)).to eq(foo: "bar")
  end

  describe "Serializers" do
    it "serializes and deserializes with JSON adapter" do
      payload = Specwrk::Store::Serializers::JSON.dump(foo: "bar")

      expect(payload).to be_a(String)
      expect(Specwrk::Store::Serializers::JSON.load(payload)).to eq(foo: "bar")
    end

    it "serializes and deserializes with MessagePack adapter" do
      payload = Specwrk::Store::Serializers::MessagePack.dump(foo: "bar")

      expect(payload).to be_a(String)
      expect(Specwrk::Store::Serializers::MessagePack.load(payload)).to eq(foo: "bar")
    end
  end

  it "raises on unsupported serializer" do
    expect { described_class.resolve("yaml") }.to raise_error(ArgumentError)
  end
end
