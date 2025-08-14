# frozen_string_literal: true

require "listen"

module Specwrk
  class Watcher
    class Config
      def self.load(file)
        if file && File.exist?(file)
          new(false).tap { |instance| instance.instance_eval(File.read(file), file, 1) }
        else
          new
        end
      end

      def initialize(default_config = true)
        if default_config
          @mappings = [
            [/_spec\.rb$/, proc { |changed_file_path| changed_file_path }]
          ]

          @ignore_patterns = [/^(?!.*\.rb$).+/]
        else
          @mappings = []
          @ignore_patterns = []
        end
      end

      def map(pattern, &block)
        @mappings << [pattern, block]
      end

      def ignore(*patterns)
        @ignore_patterns.concat(patterns)
      end

      def spec_files_for(path)
        return [] if @ignore_patterns.any? { |pattern| pattern.match? path }

        @mappings.map do |pattern, block|
          next unless pattern.match? path

          block.call(path)
        end.flatten.compact.uniq
      end
    end

    def self.watch(dir, queue, watchfile)
      instance = new(dir, queue, watchfile)

      instance.start
    end

    def initialize(dir, queue, watchfile = "Specwrk.watchfile.rb")
      @dir = dir
      @queue = queue
      @config = Config.load(watchfile)
    end

    def start
      listener.start
    end

    def push(paths)
      paths.each do |path|
        relative_path = Pathname.new(path).relative_path_from(Pathname.new(dir)).to_s

        spec_files = config.spec_files_for(relative_path)

        spec_files.each do |spec_file_path|
          queue.push(spec_file_path) if File.exist?(spec_file_path)
        end
      end
    end

    private

    attr_reader :dir, :queue, :config

    def listener
      @listener ||= Listen.to(dir) do |modified, added|
        push(modified)
        push(added)
      end
    end
  end
end
