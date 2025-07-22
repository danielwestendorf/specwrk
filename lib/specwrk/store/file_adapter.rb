# frozen_string_literal: true

require "json"
require "base64"

require "specwrk/store"

module Specwrk
  class Store
    class FileAdapter
      EXT = ".wrk.json"

      THREAD_POOL = Class.new do
        @work_queue = Queue.new

        @threads = Array.new(ENV.fetch("SPECWRK_SRV_FILE_ADAPTER_THREAD_COUNT", "24").to_i) do
          Thread.new do
            loop do
              @work_queue.pop.call
            end
          end
        end

        class << self
          def schedule(&blk)
            @work_queue.push blk
          end
        end
      end

      def initialize(path)
        @path = path
        FileUtils.mkdir_p(@path)
      end

      def [](key)
        read(key)
      end

      def []=(key, value)
        key_string = key.to_s
        if value.nil?
          delete(key_string)
        else
          filename = filename_for_key(key_string)
          write(filename, value)
          known_key_pairs[key_string] = filename
        end
      end

      def keys
        known_key_pairs.keys
      end

      def clear
        FileUtils.rm_rf(@path)
        FileUtils.mkdir_p(@path)

        @known_key_pairs = nil
      end

      def delete(*keys)
        encoded_globs = keys.map { |key| File.join(@path, "*_#{encode_key key}#{EXT}") }
        filenames = Dir.glob(encoded_globs)

        if filenames.length.positive?
          FileUtils.rm_f(filenames)
        end

        keys.each { |key| known_key_pairs.delete(key) }
      end

      def merge!(h2)
        multi_write(h2)
      end

      def multi_read(*read_keys)
        known_key_pairs # precache before each thread tries to look them up

        result_queue = Queue.new

        read_keys.each do |key|
          THREAD_POOL.schedule do
            result_queue.push([key.to_s, read(key.to_s)])
          end
        end

        Thread.pass until result_queue.length == read_keys.length

        results = {}
        until result_queue.empty?
          result = result_queue.pop
          next if result.last.nil?

          results[result.first] = result.last
        end

        read_keys.map { |key| [key.to_s, results[key.to_s]] if results.key?(key.to_s) }.compact.to_h # respect order requested in the returned hash
      end

      def multi_write(hash)
        known_key_pairs # precache before each thread tries to look them up

        result_queue = Queue.new

        hash_with_filenames = hash.map { |key, value| [key.to_s, [filename_for_key(key.to_s), value]] }.to_h
        hash_with_filenames.each do |key, (filename, value)|
          THREAD_POOL.schedule do
            result_queue << write(filename, value)
          end
        end

        Thread.pass until result_queue.length == hash.length
        hash_with_filenames.each { |key, (filename, _value)| known_key_pairs[key] = filename }
      end

      def empty?
        Dir.empty? @path
      end

      private

      def write(filename, value)
        tmp_filename = [filename, "tmp"].join(".")

        File.open(tmp_filename, "w") do |f|
          f.binmode
          f.write JSON.generate(value)
          f.fsync
          f.close
        end

        FileUtils.mv tmp_filename, filename
        true
      end

      def read(key)
        parse_file known_key_pairs[key] if known_key_pairs.key? key
      end

      def parse_file(filename)
        JSON.parse(File.read(filename), symbolize_names: true)
      end

      def filename_for_key(key)
        File.join(
          @path,
          [
            counter_prefix(key),
            encode_key(key)
          ].join("_")
        ) + EXT
      end

      def counter_prefix(key)
        count = keys.index(key) || counter.tap { @counter += 1 }

        "%012d" % count
      end

      def counter
        @counter ||= keys.length
      end

      def encode_key(key)
        Base64.urlsafe_encode64(key).delete("=")
      end

      def decode_key(key)
        encoded_key_part = File.basename(key).delete_suffix(EXT).split(/\A\d+_/).last
        padding_count = (4 - encoded_key_part.length % 4) % 4

        Base64.urlsafe_decode64(encoded_key_part + ("=" * padding_count))
      end

      def known_key_pairs
        @known_key_pairs ||= Dir.entries(@path).sort.reverse.map do |filename|
          next if filename.start_with? "."
          next unless filename.end_with? EXT

          file_path = File.join(@path, filename)
          [decode_key(file_path), file_path]
        end.compact.reverse.to_h
      end
    end
  end
end
