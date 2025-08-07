# frozen_string_literal: true

require "specwrk/worker/completion_formatter"

RSpec.describe Specwrk::Worker::CompletionFormatter do
  before do
    allow(RSpec::Core::Formatters).to receive(:register)
      .with(described_class, :stop)
  end

  let(:instance) { described_class.new }
  let(:group_notification) { instance_double RSpec::Core::Notifications::ExamplesNotification, notifications: notifications }

  def notification_factory(status)
    execution_result = instance_double RSpec::Core::Example::ExecutionResult,
      status: status,
      started_at: Time.now - 10,
      finished_at: Time.now,
      run_time: 10.0

    example = instance_double RSpec::Core::Example,
      id: "foo.rb:1",
      full_description: "foobar",
      execution_result: execution_result,
      metadata: {
        file_path: "foo.rb",
        line_number: 1
      }
    instance_double(RSpec::Core::Notifications::ExampleNotification, example: example)
  end

  describe "#stop" do
    subject { instance.stop(group_notification) }

    context "all examples passed" do
      let(:notifications) do
        [notification_factory(:passed), notification_factory(:passed)]
      end

      it { expect { subject }.to change(instance.examples, :length).from(0).to(2) }
    end
  end
end
