# frozen_string_literal: true

require "uri"

require "specwrk/store"

module Specwrk
  class Store
    class BaseAdapter
      class << self
        def with_lock(_uri, _key)
          yield
        end
      end

      def initialize(uri, scope)
        @uri = uri
        @scope = scope
      end

      def [](key)
        raise "Not implemented"
      end

      def []=(key, value)
        raise "Not implemented"
      end

      def keys
        raise "Not implemented"
      end

      def clear
        raise "Not implemented"
      end

      def delete(*keys)
        raise "Not implemented"
      end

      def merge!(h2)
        raise "Not implemented"
      end

      def multi_read(*read_keys)
        raise "Not implemented"
      end

      def multi_write(hash)
        raise "Not implemented"
      end

      def empty?
        raise "Not implemented"
      end

      private

      attr_reader :uri, :scope
    end
  end
end
