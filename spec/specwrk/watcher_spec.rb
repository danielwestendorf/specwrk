# frozen_string_literal: true

require "specwrk/watcher"

RSpec.describe Specwrk::Watcher::Config do
  describe ".load" do
    subject { instance.spec_files_for(input) }

    let(:instance) { described_class.load(file) }

    context "when file is nil" do
      let(:file) { nil }

      context "with a non-spec Ruby file" do
        let(:input) { "foo.rb" }
        it { is_expected.to eq([]) }
      end

      context "with a *_spec.rb file" do
        let(:input) { "foo_spec.rb" }
        it { is_expected.to eq(["foo_spec.rb"]) }
      end

      context "with a non-Ruby file" do
        let(:input) { "foo.txt" }
        it { is_expected.to eq([]) }
      end
    end

    context "when the watchfile exists" do
      let(:file) { File.join(Dir.mktmpdir, "Specwrk.watchfile.rb") }

      before do
        File.write(file, <<~RUBY)
          map(%r{\\Alib/(.+)\\.rb\\z}) { |p| p.sub(%r{\\Alib/(.+)\\.rb\\z}, 'spec/\\1_spec.rb') }
          ignore(%r{\\Aignored/})
        RUBY
      end

      context "with a mapped lib file" do
        let(:input) { "lib/thing.rb" }
        it { is_expected.to eq(["spec/thing_spec.rb"]) }
      end

      context "with an ignored path" do
        let(:input) { "ignored/whatever.rb" }
        it { is_expected.to eq([]) }
      end
    end
  end

  describe "#spec_files_for" do
    subject { instance.spec_files_for(file) }

    let(:instance) { described_class.new }

    context "with custom mappings (collect then uniq/compact)" do
      before do
        instance.map(%r{\Alib/(.+)\.rb\z}) { |p| p.sub(%r{\Alib/(.+)\.rb\z}, 'spec/\1_spec.rb') }
        instance.map(/\.rb\z/) { |p| p }
      end

      context "when the file is lib/foo.rb" do
        let(:file) { "lib/foo.rb" }
        it { is_expected.to eq(["spec/foo_spec.rb", "lib/foo.rb"]) }
      end
    end

    context "with custom ignore patterns" do
      before { instance.ignore(%r{\Atmp/}, /_legacy\.rb\z/) }

      context "when the file is under tmp/" do
        let(:file) { "tmp/a.rb" }
        it { is_expected.to be_empty }
      end

      context "when the file ends with _legacy.rb" do
        let(:file) { "models/user_legacy.rb" }
        it { is_expected.to be_empty }
      end
    end
  end
end

RSpec.describe Specwrk::Watcher do
  let(:instance) { described_class.new(dir, queue_dbl, watchfile) }
  let(:dir) { Dir.mktmpdir }
  let(:queue_dbl) { instance_double(Queue) } # mock instead of spy
  let(:watchfile) { "Specwrk.watchfile.rb" }

  let(:config_dbl) { instance_double(described_class::Config) }
  let(:listener_dbl) { instance_double(Listen::Listener, start: :started) }

  before do
    allow(described_class::Config).to receive(:load).with(watchfile).and_return(config_dbl)
    allow(Listen).to receive(:to).with(dir).and_return(listener_dbl)
  end

  describe ".watch" do
    subject { described_class.watch(dir, queue_dbl, watchfile) }

    before do
      allow(described_class).to receive(:new)
        .with(dir, queue_dbl, watchfile)
        .and_return(instance_double(described_class, start: :ok))
    end

    it { is_expected.to eq(:ok) }
  end

  describe "#start" do
    subject { instance.start }

    it "starts the listener" do
      expect(listener_dbl).to receive(:start).and_return(:started)
      is_expected.to eq(:started)
    end
  end

  describe "#push" do
    subject { instance.push(paths) }

    let(:paths) do
      [
        "#{dir}/foo",
        "#{dir}/fizz"
      ]
    end

    it "pushes files that exist to the queue_dbl" do
      expect(config_dbl).to receive(:spec_files_for)
        .with("foo")
        .and_return(["bar"])

      expect(config_dbl).to receive(:spec_files_for)
        .with("fizz")
        .and_return(["buzz", "fizzbuzz"])

      expect(File).to receive(:exist?)
        .with("bar")
        .and_return(true)

      expect(File).to receive(:exist?)
        .with("buzz")
        .and_return(true)

      expect(File).to receive(:exist?)
        .with("fizzbuzz")
        .and_return(false)

      expect(queue_dbl).to receive(:push)
        .with("bar")

      expect(queue_dbl).to receive(:push)
        .with("buzz")

      expect(queue_dbl).not_to receive(:push)
        .with("fizzbuzz")

      instance.push(paths)
    end
  end
end
