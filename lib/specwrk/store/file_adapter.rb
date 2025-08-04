# frozen_string_literal: true

require "json"
require "base64"

require "specwrk/store/base_adapter"

module Specwrk
  class Store
    class FileAdapter < BaseAdapter
      EXT = ".wrk.json"

      @work_queue = Queue.new
      @threads = []

      class << self
        def schedule_work(&blk)
          start_threads!
          @work_queue.push blk
        end

        def start_threads!
          return if @threads.length.positive?

          Array.new(ENV.fetch("SPECWRK_THREAD_COUNT", "4").to_i) do
            @threads << Thread.new do
              loop do
                @work_queue.pop.call
              end
            end
          end
        end
      end

      def [](key)
        content = read(key.to_s)
        return unless content

        JSON.parse(content, symbolize_names: true)
      end

      def []=(key, value)
        key_string = key.to_s
        if value.nil?
          delete(key_string)
        else
          filename = filename_for_key(key_string)
          write(filename, JSON.generate(value))
          known_key_pairs[key_string] = filename
        end
      end

      def keys
        known_key_pairs.keys
      end

      def clear
        FileUtils.rm_rf(path)
        FileUtils.mkdir_p(path)

        @known_key_pairs = nil
      end

      def delete(*keys)
        filenames = keys.map { |key| known_key_pairs[key] }.compact

        FileUtils.rm_f(filenames)

        keys.each { |key| known_key_pairs.delete(key) }
      end

      def merge!(h2)
        multi_write(h2)
      end

      def multi_read(*read_keys)
        known_key_pairs # precache before each thread tries to look them up

        result_queue = Queue.new

        read_keys.each do |key|
          self.class.schedule_work do
            result_queue.push([key.to_s, read(key)])
          end
        end

        Thread.pass until result_queue.length == read_keys.length

        results = {}
        until result_queue.empty?
          result = result_queue.pop
          next if result.last.nil?

          results[result.first] = JSON.parse(result.last, symbolize_names: true)
        end

        read_keys.map { |key| [key.to_s, results[key.to_s]] if results.key?(key.to_s) }.compact.to_h # respect order requested in the returned hash
      end

      def multi_write(hash)
        known_key_pairs # precache before each thread tries to look them up

        result_queue = Queue.new

        hash_with_filenames = hash.map { |key, value| [key.to_s, [filename_for_key(key.to_s), value]] }.to_h
        hash_with_filenames.each do |key, (filename, value)|
          content = JSON.generate(value)

          self.class.schedule_work do
            result_queue << write(filename, content)
          end
        end

        Thread.pass until result_queue.length == hash.length
        hash_with_filenames.each { |key, (filename, _value)| known_key_pairs[key] = filename }
      end

      def empty?
        Dir.empty? path
      end

      private

      def write(filename, content)
        tmp_filename = [filename, "tmp"].join(".")

        File.binwrite(tmp_filename, content)

        FileUtils.mv tmp_filename, filename
        true
      end

      def read(key)
        File.read(known_key_pairs[key]) if known_key_pairs.key? key
      end

      def filename_for_key(key)
        File.join(
          path,
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

      def path
        @path ||= File.join(uri.path, scope).tap do |full_path|
          FileUtils.mkdir_p(full_path)
        end
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
        @known_key_pairs ||= Dir.entries(path).sort.map do |filename|
          next if filename.start_with? "."
          next unless filename.end_with? EXT

          file_path = File.join(path, filename)
          [decode_key(filename), file_path]
        end.compact.to_h
      end
    end
  end
end
