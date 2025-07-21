# frozen_string_literal: true

require "tmpdir"

require "specwrk/filestore"

RSpec.describe Specwrk::Filestore do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, "store.json") }

  after do
    FileUtils.remove_entry(dir)
  end

  describe "#with_lock" do
    context "when store is empty" do
      it "persists initial hash" do
        result = described_class[path].with_lock do |h|
          expect(h).to eq({})
          h[:foo] = "bar"
          result = "fizbuzz"
        end

        data = JSON.parse(File.read(path), symbolize_names: true)
        expect(data).to eq(foo: "bar")
        expect(result).to eq("fizbuzz")
      end
    end

    context "when store has existing data" do
      before do
        File.write(path, {existing: "data"}.to_json)
      end

      it "yields existing data and persists changes" do
        described_class[path].with_lock do |h|
          expect(h).to eq(existing: "data")
          h[:new] = "value"
        end

        data = JSON.parse(File.read(path), symbolize_names: true)
        expect(data).to eq(existing: "data", new: "value")
      end
    end

    context "when file contains invalid JSON" do
      before do
        File.write(path, "invalid json")
      end

      it "treats invalid content as empty hash and persists changes" do
        described_class[path].with_lock do |h|
          expect(h).to eq({})
          h[:key] = "value"
        end

        data = JSON.parse(File.read(path), symbolize_names: true)
        expect(data).to eq(key: "value")
      end
    end

    context "locking" do
      it "creates a lock file during with_lock" do
        described_class[path].with_lock do |h|
          expect(File).to exist("#{path}.lock")
        end
      end

      it "is thread-safe and persists cumulative updates" do
        10.times.map do
          Thread.new do
            described_class[path].with_lock do |h|
              h[:count] = (h[:count] || 0) + 1
            end
          end
        end.each(&:join)

        data = JSON.parse(File.read(path), symbolize_names: true)
        expect(data).to eq(count: 10)
      end
    end
  end
end
