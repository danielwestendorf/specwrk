require "specwrk/worker/executor"

RSpec.describe Specwrk::Worker::Executor do
  let(:instance) { described_class.new }

  describe "#failure" do
    subject { instance.failure }

    it { is_expected.to be(instance.completion_formatter.failure) }
  end

  describe "#examples" do
    subject { instance.examples }

    it { is_expected.to be(instance.completion_formatter.examples) }
  end

  describe "#final_output" do
    subject { instance.final_output }

    it { is_expected.to be(instance.progress_formatter.final_output) }
  end

  describe "#run" do
    let(:examples) { [{id: "foo.rb:1"}, {id: "bar.rb:1"}] }
    let(:options_dbl) { instance_double(RSpec::Core::ConfigurationOptions) }
    let(:runner_dbl) { instance_double(RSpec::Core::Runner) }

    it "calls the rspec runner" do
      expect(instance).to receive(:reset!)
        .and_return(true)

      expect(instance).to receive(:rspec_options)
        .and_return(["baz"])

      expect(RSpec::Core::ConfigurationOptions).to receive(:new)
        .with(["baz", "foo.rb:1", "bar.rb:1"])
        .and_return(options_dbl)

      expect(RSpec::Core::Runner).to receive(:new)
        .with(options_dbl)
        .and_return(runner_dbl)

      expect(runner_dbl).to receive(:run)
        .with($stderr, $stdout)
        .and_return("🇺🇸!Big Success!🇺🇸")

      expect(instance.run(examples)).to eq("🇺🇸!Big Success!🇺🇸")
    end
  end

  describe "#reset!" do
    around do |ex|
      previous_force_quit = Specwrk.force_quit
      Specwrk.force_quit = true
      ex.run
      Specwrk.force_quit = previous_force_quit
    end

    it "resets everything to a clean slate" do
      expect(instance.completion_formatter.examples).to receive(:clear)
      expect(RSpec).to receive(:clear_examples)
        .and_return(true)

      expect(RSpec.world).to receive(:non_example_failure=)
        .with(false)
        .and_return(false)

      expect(RSpec.world).to receive(:wants_to_quit=)
        .with(Specwrk.force_quit)
        .and_return(false)

      expect(RSpec.configuration).to receive(:add_formatter)
        .with(instance.progress_formatter)

      expect(RSpec.configuration).to receive(:add_formatter)
        .with(instance.completion_formatter)

      expect(RSpec.configuration).to receive(:add_formatter)
        .with(Specwrk::Worker::NullFormatter)

      expect(RSpec.configuration).to receive(:silence_filter_announcements=)
        .with(true)
        .and_return(true)

      expect(instance.reset!).to eq(true)
    end
  end

  describe "#progress_formatter" do
    subject { instance.progress_formatter }

    it { is_expected.to be_kind_of(Specwrk::Worker::ProgressFormatter) }
  end

  describe "#completion_formatter" do
    subject { instance.completion_formatter }

    it { is_expected.to be_kind_of(Specwrk::Worker::CompletionFormatter) }
  end

  describe "#rspec_options" do
    subject { instance.rspec_options }

    context "SPECWRK_OUT defined" do
      before { stub_const("ENV", {"SPECWRK_OUT" => "/tmp/foobar", "SPECWRK_ID" => "specwrk-worker-42"}) }

      it { is_expected.to eq(%w[--format json --out /tmp/foobar/specwrk-worker-42.json]) }
    end
    context "SPECWRK_OUT blank"
  end
end
