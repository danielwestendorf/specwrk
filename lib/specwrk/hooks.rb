# frozen_string_literal: true

module Specwrk
  module Hooks
    class << self
      def register(name, &block)
        raise ArgumentError, "a block is required" unless block

        hooks[name] << block
        block
      end

      def run(name, *objects)
        hooks.fetch(name, []).dup.each { |hook| hook.call(*objects) }
        nil
      end

      def load_file(file)
        Kernel.load(file) if file && File.file?(file)
      end

      def reset!
        @hooks = nil
      end

      private

      def hooks
        @hooks ||= Hash.new { |registry, name| registry[name] = [] }
      end
    end
  end
end
