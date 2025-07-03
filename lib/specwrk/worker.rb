# frozen_string_literal: true

require "stringio"

require "specwrk/client"
require "specwrk/worker/executor"

module Specwrk
  class Worker
    def self.run!
      new.run
    end

    def initialize
      Process.setproctitle ENV.fetch("SPECWRK_ID", "specwrk-worker")

      @running = true
      @client = Client.new
      @executor = Executor.new
      @heartbeat_thread ||= Thread.new do
        thump
      end
    end

    def run
      Client.wait_for_server!

      loop do
        break if Specwrk.force_quit

        execute
      rescue CompletedAllExamplesError, NoMoreExamplesError
        # TODO: Sleep on NoMoreExamplesError to allow for retries
        break
      end

      executor.final_output.tap(&:rewind).each_line { |line| $stdout.write line }

      @heartbeat_thread.kill
      client.close
    rescue Errno::ECONNREFUSED
      warn "\nServer at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} is refusing connections, exiting..."
    rescue Errno::ECONNRESET
      warn "\nServer at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} stopped responding to connections, exiting..."
    end

    def execute
      executor.run client.fetch_examples
      complete_examples
    rescue UnhandledResponseError => e
      # If fetching examples fails we can just try again so warn and return
      warn e.message
    end

    def complete_examples
      client.complete_examples executor.examples
    rescue UnhandledResponseError => e
      # I do not think we should so lightly abandon the completion of executed examples
      # try to complete until successful or terminated
      warn e.message

      sleep 1
      retry
    end

    def thump
      while running && !Specwrk.force_quit
        begin
          client.heartbeat if client.last_request_at.nil? || client.last_request_at < Time.now - 10
        rescue
          warn "Heartbeat failed!"
        end

        sleep 1
      end
    end

    private

    attr_reader :running, :client, :executor

    def warn(msg)
      super("#{ENV.fetch("SPECWRK_ID", "specwrk-worker")}: #{msg}")
    end
  end
end
