# frozen_string_literal: true

require "specwrk/store/base_adapter"

module Specwrk
  class Store
    class MemoryAdapter < BaseAdapter
      @@stores = Hash.new { |hash, key| hash[key] = {} }

      class << self
        def clear
          @@stores.values.each(&:clear)
        end
      end

      def [](key)
        store[key]
      end

      def []=(key, value)
        store[key] = value
      end

      def keys
        store.keys
      end

      def clear
        store.clear
      end

      def delete(*keys)
        keys.each { |key| store.delete(key) }
      end

      def merge!(h2)
        store.merge!(h2)
      end

      def multi_read(*read_keys)
        store.slice(*read_keys)
      end

      def multi_write(hash)
        merge!(hash)
      end

      def empty?
        store.keys.length.zero?
      end

      private

      def store
        @store ||= @@stores[scope]
      end
    end
  end
end
