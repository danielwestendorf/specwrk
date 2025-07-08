# frozen_string_literal: true

require "specwrk/version"

module Specwrk
  Error = Class.new(StandardError)

  # HTTP Client Errors
  ClientError = Class.new(Error)
  UnhandledResponseError = Class.new(ClientError)
  WaitingForSeedError = Class.new(ClientError)
  NoMoreExamplesError = Class.new(ClientError)
  CompletedAllExamplesError = Class.new(ClientError)

  @force_quit = false
  @starting_pid = Process.pid

  class << self
    attr_accessor :force_quit, :net_http
    attr_reader :starting_pid

    def wait_for_pids_exit(pids)
      exited_pids = {}

      loop do
        pids.each do |pid|
          next if exited_pids.key? pid

          _, status = Process.waitpid2(pid, Process::WNOHANG)
          exited_pids[pid] = status.exitstatus if status&.exitstatus
        rescue Errno::ECHILD
          exited_pids[pid] = 1
        end

        break if exited_pids.keys.length == pids.length
        sleep 0.1
      end

      exited_pids
    end
  end
end
