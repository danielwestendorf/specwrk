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

    def human_readable_duration(total_seconds, precision: 2)
      secs = total_seconds.to_f
      hours = (secs / 3600).to_i
      mins = ((secs % 3600) / 60).to_i
      seconds = secs % 60

      parts = []
      parts << "#{hours}h" if hours.positive?
      parts << "#{mins}m" if mins.positive?
      if seconds.positive?
        sec_str = format("%0.#{precision}f", seconds).sub(/\.?0+$/, "")
        parts << "#{sec_str}s"
      end
      parts.join(" ")
    end
  end
end
