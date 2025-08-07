# frozen_string_literal: true

require "tempfile"

require "rspec"

require "specwrk/worker/progress_formatter"
require "specwrk/worker/completion_formatter"
require "specwrk/worker/null_formatter"

module Specwrk
  class Worker
    class Executor
      def examples
        completion_formatter.examples
      end

      def final_output
        progress_formatter.final_output
      end

      def run(examples)
        reset!

        example_ids = examples.map { |example| example[:id] }

        options = RSpec::Core::ConfigurationOptions.new rspec_options + example_ids
        RSpec::Core::Runner.new(options).run($stderr, $stdout)
      end

      # https://github.com/skroutz/rspecq/blob/341383ce3ca25f42fad5483cbb6a00ba1c405570/lib/rspecq/worker.rb#L208-L224
      def reset!
        completion_formatter.examples.clear

        RSpec.clear_examples
        RSpec.configuration.backtrace_formatter.filter_gem "specwrk"

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

        RSpec.configuration.add_formatter progress_formatter
        RSpec.configuration.add_formatter completion_formatter

        # This formatter may be specified by the runner options so
        # it will be initialized by RSpec
        RSpec.configuration.add_formatter NullFormatter

        true
      end

      # We want to persist this object between example runs
      def progress_formatter
        @progress_formatter ||= ProgressFormatter.new($stdout)
      end

      def completion_formatter
        @completion_formatter ||= CompletionFormatter.new
      end

      def rspec_options
        @rspec_options ||= if ENV["SPECWRK_OUT"]
          ["--format", "json", "--out", File.join(ENV["SPECWRK_OUT"], "#{ENV.fetch("SPECWRK_ID", "specwrk-worker")}.json")]
        else
          ["--format", "Specwrk::Worker::NullFormatter"]
        end
      end
    end
  end
end
