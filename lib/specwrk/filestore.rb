# frozen_string_literal: true

require "fileutils"

module Specwrk
  class Filestore
    @mutexes = {}
    @mutexes_mutex = Mutex.new # 🐢🐢🐢🐢

    class << self
      def [](path)
        new(path)
      end

      def mutex_for(path)
        @mutexes_mutex.synchronize do
          @mutexes[path] ||= Mutex.new
        end
      end
    end

    def initialize(path)
      @path = path
      @tmpfile_path = @path + ".tmp"
      @lock_path = @path + ".lock"

      FileUtils.mkdir_p File.dirname(@path)
      File.open(@path, "a") {} # multi-process and multi-thread safe touch
    end

    def with_lock
      self.class.mutex_for(@path).synchronize do
        lock_file.flock(File::LOCK_EX)

        hash = read
        result = yield(hash)

        # Will truncate if already exists
        File.open(@tmpfile_path, "w") do |tmpfile|
          tmpfile.write(hash.to_json)
          tmpfile.fsync
          tmpfile.close
        end

        File.rename(@tmpfile_path, @path)
        result
      ensure
        lock_file.flock(File::LOCK_UN)
      end
    end

    private

    def lock_file
      @lock_file ||= File.open(@lock_path, "w")
    end

    def read
      JSON.parse(File.read(@path), symbolize_names: true)
    rescue JSON::ParserError
      {}
    end
  end
end
