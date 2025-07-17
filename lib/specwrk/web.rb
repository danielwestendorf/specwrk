# frozen_string_literal: true

require "specwrk/queue"

module Specwrk
  class Web
    PENDING_QUEUES = Queue.new { |h, key| h[key] = PendingQueue.new }
    PROCESSING_QUEUES = Queue.new { |h, key| h[key] = Queue.new }
    COMPLETED_QUEUES = Queue.new { |h, key| h[key] = CompletedQueue.new }
    WORKERS = Hash.new { |h, key| h[key] = Hash.new { |h, key| h[key] = {} } }

    def self.clear_queues
      [PENDING_QUEUES, PROCESSING_QUEUES, COMPLETED_QUEUES, WORKERS].each(&:clear)
    end

    def self.clear_run_queues(run)
      [PENDING_QUEUES, PROCESSING_QUEUES, COMPLETED_QUEUES, WORKERS].each do |queue|
        queue.delete(run)
      end
    end
  end
end
