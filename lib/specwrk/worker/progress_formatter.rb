# frozen_string_literal: true

require "tempfile"

RSpec::Support.require_rspec_core "formatters/base_text_formatter"
RSpec::Support.require_rspec_core "formatters/console_codes"

module Specwrk
  class Worker
    class ProgressFormatter
      RSpec::Core::Formatters.register self, :example_passed, :example_pending, :example_failed, :dump_failures, :dump_pending
      attr_reader :output, :final_output

      def initialize(output)
        @output = output

        @final_output = Tempfile.new
        @final_output.define_singleton_method(:tty?) { true }
        @final_output.sync = true
      end

      def example_passed(_notification)
        output.print RSpec::Core::Formatters::ConsoleCodes.wrap(".", :success)
      end

      def example_pending(_notification)
        output.print RSpec::Core::Formatters::ConsoleCodes.wrap("*", :pending)
      end

      def example_failed(_notification)
        output.print RSpec::Core::Formatters::ConsoleCodes.wrap("F", :failure)
      end

      def dump_failures(notification)
        return if notification.failure_notifications.empty?
        final_output.puts notification.fully_formatted_failed_examples
      end

      def dump_pending(notification)
        return if notification.pending_examples.empty?
        final_output.puts notification.fully_formatted_pending_examples
      end
    end
  end
end
