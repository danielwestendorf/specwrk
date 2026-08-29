# frozen_string_literal: true

require "tmpdir"

require "specwrk/cli"

RSpec.describe Specwrk::CLI::HooksConfigurable do
  let(:command_class) do
    Class.new(Dry::CLI::Command) do
      include Specwrk::CLI::HooksConfigurable
    end
  end

  before do
    stub_const("ENV", ENV.to_h)
  end

  it "adds a hooks option with Specwrk.hooks.rb as the default" do
    option = command_class.options.find { |candidate| candidate.name == :hooks }

    expect(option.default).to eq("Specwrk.hooks.rb")
  end

  it "loads an overridden hooks file and exposes its absolute path to child processes" do
    Dir.mktmpdir("specwrk-hooks") do |dir|
      file = File.join(dir, "custom-hooks.rb")
      File.write(file, <<~RUBY)
        Specwrk::Hooks.register(:configured_hook) { |calls| calls << :configured }
      RUBY
      calls = []

      Dir.chdir(dir) { command_class.setup(hooks: "custom-hooks.rb") }
      Specwrk::Hooks.run(:configured_hook, calls)

      expect(calls).to eq([:configured])
      expect(ENV["SPECWRK_HOOKS_FILE"]).to eq(File.realpath(file))
    end
  end

  it "is available on every lifecycle command" do
    command_classes = [
      Specwrk::CLI::Seed,
      Specwrk::CLI::Work,
      Specwrk::CLI::Serve,
      Specwrk::CLI::Start,
      Specwrk::CLI::Watch
    ]

    expect(command_classes).to all(satisfy do |klass|
      klass.options.any? { |option| option.name == :hooks }
    end)
  end
end
