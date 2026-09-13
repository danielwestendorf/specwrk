# frozen_string_literal: true

require "specwrk/list_examples"
require "specwrk/client"

module Specwrk
  class SeedLoop
    def self.loop!(ipc)
      Hooks.run(:before_seed)
      Client.wait_for_server!

      loop do
        break if Specwrk.force_quit

        files = ipc.read

        next unless files
        examples = ListExamples.new(files.split(" ")).examples

        client = Client.new
        client.seed(examples, 0)
        Hooks.run(:after_seed, examples)
        client.close

        ipc.write examples.length
      end
    end
  end
end
