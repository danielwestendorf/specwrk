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

      executor.flush_log
      executor.final_output.tap(&:rewind).each_line { |line| final_output.write line }

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
      batch = next_examples
      executor.run batch
      @next_examples = nil
      complete_examples batch
    rescue UnhandledResponseError => e
      # If fetching examples via next_exampels fails we can just try again so warn and return
      # Expects complete_examples to rescue this error if raised in that method
      warn e.message
    end

    def next_examples
      return @next_examples if @next_examples&.length&.positive?
      client.fetch_examples
    end

    def complete_examples(batch = [])
      @next_examples = client.complete_and_fetch_examples executor.examples + unexecuted_examples(batch)
    rescue UnhandledResponseError => e
      # I do not think we should so lightly abandon the completion of executed examples
      # try to complete until successful or terminated
      warn e.message

      sleep 1
      retry
    end

    # Failure results for examples that were part of the batch but which the
    # RSpec runner produced no result for — e.g. the run aborted in a
    # `before(:suite)` hook or a spec file failed to load, so zero examples
    # executed.
    #
    # Every example popped from the server MUST be reported back. The server
    # only removes examples from its processing store when a completion names
    # them, and its expiry/requeue path only reclaims work from workers whose
    # heartbeat has gone stale — a live worker's stranded examples are never
    # reclaimed. If they were silently dropped here, `processing` would never
    # empty, the run-complete condition could never be met, and every worker
    # would poll for more work forever. Reporting them as failed lets the run
    # finish loudly (and lets `--max-retries` retry them like any other
    # failure).
    def unexecuted_examples(batch)
      return [] if batch.nil? || batch.empty?

      executed_ids = executor.examples.map { |example| example[:id] }
      now = Time.now

      batch.reject { |example| executed_ids.include?(example[:id]) }.map do |example|
        {
          id: example[:id],
          full_description: example[:full_description] || example[:id],
          status: "failed",
          file_path: example[:file_path],
          line_number: example[:line_number],
          started_at: now.iso8601(6),
          finished_at: now.iso8601(6),
          run_time: 0.0,
          exception: {
            class: "Specwrk::Error",
            message: "Example was assigned to #{ENV.fetch("SPECWRK_ID", "specwrk-worker")} but the RSpec runner produced no result for it. " \
                     "This usually means the run aborted before executing any examples — check for an error in a `before(:suite)` hook or a spec file that fails to load.",
            backtrace: []
          }
        }
      end
    end

    def thump
      while running && !Specwrk.force_quit
        sleep 10

        begin
          client.heartbeat if client.last_request_at.nil? || client.last_request_at < Time.now - 9
        rescue
          warn "Heartbeat failed!"
        end
      end
    end

    private

    attr_reader :running, :client, :executor

    def final_output
      $final_output || $stdout # standard:disable Style/GlobalVars
    end

    def status
      return 0 if @all_examples_completed && client.worker_status.zero?
      return 1 if Specwrk.force_quit

      client.worker_status
    end

    def warn(msg)
      super("#{ENV.fetch("SPECWRK_ID", "specwrk-worker")}: #{msg}")
    end
  end
end
