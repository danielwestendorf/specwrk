# frozen_string_literal: true

require "tmpdir"

require "specwrk/store/file_adapter"

RSpec.describe Specwrk::Store::FileAdapter do
  let(:path) { File.join(uri.path, scope).tap { |path| FileUtils.mkdir_p(path) } }
  let(:uri) { URI("file://#{Dir.tmpdir}") }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri, scope) }

  def write(key, value)
    @counter ||= -1
    @counter += 1
    filename = "#{"%012d" % @counter}_#{encode_key key}#{Specwrk::Store::FileAdapter::EXT}"
    File.write(File.join(path, filename), JSON.generate(value))
  end

  def encode_key(key)
    Base64.urlsafe_encode64(key.to_s).delete("=")
  end

  def current_filenames
    Dir.glob(File.join(path, "*#{Specwrk::Store::FileAdapter::EXT}"))
  end

  describe ".schedule_work" do
    let(:klass) do
      Class.new do
        attr_accessor :result

        def process
          1
        end
      end
    end

    it "processes the work when able" do
      instance = klass.new
      result = Queue.new

      100.times do
        described_class.schedule_work do
          result << instance.process
        end
      end

      Thread.pass until result.length == 100

      100.times do
        expect(result.pop).to eq(1)
      end

      expect(result.empty?).to eq(true)
    end
  end

  describe "#[]" do
    subject { instance[key] }

    let(:key) { "foobar" }
    let(:value) { {foo: "bar"} }

    before { write(key, value) }

    it { is_expected.to eq(value) }
  end

  describe "#[]=" do
    subject { instance[key] = value }

    let(:key) { "foobar" }
    let(:value) { {foo: "bar"} }

    it { expect { subject }.to change { current_filenames.length }.from(0).to(1) }

    context "value is set to nil deletes the file instead" do
      let(:value) { nil }

      before { write(key, value) }

      it { expect { subject }.to change { current_filenames.length }.from(1).to(0) }
    end
  end

  describe "#keys" do
    subject { instance.keys }

    let(:ordered_keys) { ("a".."z").to_a.shuffle }

    before { ordered_keys.each.with_index { |k, i| write(k, i) } }

    it { is_expected.to eq(ordered_keys) }
  end

  describe "#clear" do
    subject { instance.clear }

    before do
      write(:a, "1")
      write(:b, "2")
    end

    it { expect { subject }.to change { current_filenames.length }.from(2).to(0) }
  end

  describe "#delete" do
    subject { instance.delete("a", "b") }

    before do
      write(:a, "1")
      write(:b, "2")
    end

    it { expect { subject }.to change { current_filenames.length }.from(2).to(0) }
  end

  describe "#merge! and #multi_write" do
    subject { instance.merge!(b: 1, a: 2) }

    it { expect { subject }.to change { current_filenames.first&.split("_")&.last }.from(nil).to("#{encode_key("b")}#{Specwrk::Store::FileAdapter::EXT}") }
    it { expect { subject }.to change { current_filenames.last&.split("_")&.last }.from(nil).to("#{encode_key("a")}#{Specwrk::Store::FileAdapter::EXT}") }
  end

  describe "#multi_read" do
    subject { instance.multi_read("b", "a") }

    before do
      write("a", 1)
      write("b", 2)
    end

    it { is_expected.to eq("b" => 2, "a" => 1) }
  end

  describe "#empty?" do
    subject { instance.empty? }

    context "without any files in the path" do
      it { is_expected.to eq(true) }
    end

    context "without any files in the path" do
      before { write("a", 1) }

      it { is_expected.to eq(false) }
    end
  end
end
