# frozen_string_literal: true

require "tempfile"

require "rspec/core"

module Specwrk
  class ListExamples
    def initialize(dir)
      @dir = dir
    end

    def examples
      reset!
      return @examples if defined?(@examples)

      @examples = []

      RSpec.configuration.files_or_directories_to_run = @dir
      RSpec::Core::Formatters.register self.class, :stop
      RSpec.configuration.add_formatter(self)

      unless RSpec::Core::Runner.new(options).run($stderr, out).zero?
        out.tap(&:rewind).each_line { |line| $stdout.print line }
      end

      @examples
    end

    # Called as the formatter
    def stop(group_notification)
      group_notification.notifications.map do |notification|
        @examples << {
          id: notification.example.id,
          file_path: notification.example.metadata[:file_path]
        }
      end
    end

    private

    def reset!
      return unless ENV["SPECWRK_SEED"]
      RSpec.clear_examples

      # see https://github.com/rspec/rspec-core/pull/2723
      if Gem::Version.new(RSpec::Core::Version::STRING) <= Gem::Version.new("3.9.1")
        RSpec.world.instance_variable_set(
          :@example_group_counts_by_spec_file, Hash.new(0)
        )
      end

      # RSpec.clear_examples does not reset those, which causes issues when
      # a non-example error occurs (subsequent jobs are not executed)
      RSpec.world.non_example_failure = false

      # we don't want an error that occured outside of the examples (which
      # would set this to `true`) to stop the worker
      RSpec.world.wants_to_quit = Specwrk.force_quit

      RSpec.configuration.silence_filter_announcements = true
      RSpec.configuration.filter_manager.inclusions.clear
      RSpec.configuration.filter_manager.exclusions.clear

      true
    end

    def out
      @out ||= Tempfile.new.tap do |f|
        f.define_singleton_method(:tty?) { true }
      end
    end

    def options
      RSpec::Core::ConfigurationOptions.new(
        ["--dry-run", *RSpec.configuration.files_to_run]
      )
    end
  end
end
