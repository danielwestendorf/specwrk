# frozen_string_literal: true

require "specwrk/worker/completion_formatter"

RSpec.describe Specwrk::Worker::CompletionFormatter do
  before do
    allow(RSpec::Core::Formatters).to receive(:register)
      .with(described_class, :stop)
  end

  let(:instance) { described_class.new }
  let(:group_notification) { instance_double RSpec::Core::Notifications::ExamplesNotification, notifications: notifications }

  def notification_factory(status, exception = nil)
    execution_result = instance_double RSpec::Core::Example::ExecutionResult,
      status: status,
      started_at: Time.now - 10,
      finished_at: Time.now,
      run_time: 10.0

    example = instance_double RSpec::Core::Example,
      id: "foo.rb:1",
      full_description: "foobar",
      execution_result: execution_result,
      exception: exception,
      metadata: {
        file_path: "foo.rb",
        line_number: 1
      }

    if status == :failed
      instance_double(RSpec::Core::Notifications::FailedExampleNotification, example: example, formatted_backtrace: "foobar")
    else
      instance_double(RSpec::Core::Notifications::ExampleNotification, example: example)
    end
  end

  describe "#stop" do
    subject { instance.stop(group_notification) }

    context "all examples passed" do
      let(:notifications) do
        [notification_factory(:passed), notification_factory(:passed), notification_factory(:failed, StandardError.new)]
      end

      it { expect { subject }.to change(instance.examples, :length).from(0).to(3) }
    end
  end
end
