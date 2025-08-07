# frozen_string_literal: true

module Specwrk
  class Worker
    class CompletionFormatter
      RSpec::Core::Formatters.register self, :stop

      attr_reader :examples

      def initialize
        @examples = []
      end

      def stop(group_notification)
        group_notification.notifications.map do |notification|
          examples << {
            id: notification.example.id,
            full_description: notification.example.full_description,
            status: notification.example.execution_result.status,
            file_path: notification.example.metadata[:file_path],
            line_number: notification.example.metadata[:line_number],
            started_at: notification.example.execution_result.started_at.iso8601(6),
            finished_at: notification.example.execution_result.finished_at.iso8601(6),
            run_time: notification.example.execution_result.run_time
          }
        end
      end
    end
  end
end
