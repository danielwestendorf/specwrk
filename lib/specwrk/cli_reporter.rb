# frozen_string_literal: true

require "time"

require "specwrk/client"

require "rspec"
require "rspec/core/formatters/helpers"
require "rspec/core/formatters/console_codes"

module Specwrk
  class CLIReporter
    def report
      unless Client.connect?
        puts colorizer.wrap("Cannot connect to server to generate report. Assuming failure.", :red)
        return 1
      end

      puts "\nFinished in #{total_duration} " \
                          "(total execution time of #{total_run_time})\n"

      client.shutdown

      if failure_count.positive?
        puts colorizer.wrap(totals_line, :red)
        1
      elsif pending_count.positive?
        puts colorizer.wrap(totals_line, :yellow)
        0
      else
        puts colorizer.wrap(totals_line, :green)
        0
      end
    rescue Specwrk::UnhandledResponseError => e
      puts colorizer.wrap("Cannot report, #{e.message}.", :red)

      client.shutdown

      1
    end

    private

    def totals_line
      summary = RSpec::Core::Formatters::Helpers.pluralize(example_count, "example") +
        ", " + RSpec::Core::Formatters::Helpers.pluralize(failure_count, "failure")
      summary += ", #{pending_count} pending" if pending_count > 0

      summary
    end

    def report_data
      @report_data ||= client.report
    end

    def total_duration
      Time.parse(report_data.dig(:meta, :last_finished_at)) - Time.parse(report_data.dig(:meta, :first_started_at))
    end

    def total_run_time
      report_data.dig(:meta, :total_run_time)
    end

    def failure_count
      report_data.dig(:meta, :failures)
    end

    def pending_count
      report_data.dig(:meta, :pending)
    end

    def example_count
      report_data.dig(:examples).length
    end

    def client
      @client ||= Client.new
    end

    def colorizer
      ::RSpec::Core::Formatters::ConsoleCodes
    end
  end
end
