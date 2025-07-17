# frozen_string_literal: true

require "stringio"
require "fileutils"

require "specwrk/client"
require "specwrk/worker/executor"

module Specwrk
  class Worker
    def self.run!
      new.run
    end

    def initialize
      Process.setproctitle ENV.fetch("SPECWRK_ID", "specwrk-worker")
      FileUtils.mkdir_p(ENV["SPECWRK_OUT"]) if ENV["SPECWRK_OUT"]

      @running = true
      @client = Client.new
      @executor = Executor.new
      @all_examples_completed = false
      @seed_waits = ENV.fetch("SPECWRK_SEED_WAITS", "10").to_i
      @heartbeat_thread ||= Thread.new do
        thump
      end
    end

    def run
      Client.wait_for_server!

      loop do
        break if Specwrk.force_quit

        execute
      rescue CompletedAllExamplesError
        @all_examples_completed = true
        break
      rescue NoMoreExamplesError
        # Wait for the other processes (workers) on the same host to finish
        # This will cause workers to 'hang' until all work has been completed
        # TODO: break here if all the other worker processes on this host are done executing examples
        sleep 0.5
      rescue WaitingForSeedError
        @seed_wait_count ||= 0
        @seed_wait_count += 1

        if @seed_wait_count <= @seed_waits
          warn "No examples seeded yet, waiting..."
          sleep 1
        else
          warn "No examples seeded, giving up!"
          break
        end
      end

      executor.final_output.tap(&:rewind).each_line { |line| $stdout.write line }

      @heartbeat_thread.kill
      client.close

      status
    rescue Errno::ECONNREFUSED
      warn "\nServer at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} is refusing connections, exiting..."
      1
    rescue Errno::ECONNRESET
      warn "\nServer at #{ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138")} stopped responding to connections, exiting..."
      1
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
        sleep 10

        begin
          client.heartbeat if client.last_request_at.nil? || client.last_request_at < Time.now - 30
        rescue
          warn "Heartbeat failed!"
        end
      end
    end

    private

    attr_reader :running, :client, :executor

    def status
      return 1 if !executor.example_processed && !@all_examples_completed
      return 1 if executor.failure
      return 1 if Specwrk.force_quit

      0
    end

    def warn(msg)
      super("#{ENV.fetch("SPECWRK_ID", "specwrk-worker")}: #{msg}")
    end
  end
end
