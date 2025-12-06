# frozen_string_literal: true

require "uri"

module Specwrk
  class Store
    class << self
      def with_lock(uri, key)
        adapter_klass(uri).with_lock(uri, key) { yield }
      end

      def adapter_klass(uri)
        case uri.scheme
        when "memory"
          require "specwrk/store/memory_adapter" unless defined?(MemoryAdapter)

          MemoryAdapter
        when "file"
          require "specwrk/store/file_adapter" unless defined?(FileAdapter)

          FileAdapter
        when /redis/
          begin
            require "specwrk/store/redis_adapter" unless defined?(RedisAdapter)
          rescue LoadError
            warn "Unable use RedisAdapter with #{uri}, gem not found. Add `gem 'specwrk-store-redis_adapter'` to your Gemfile and bundle install."
            exit(1)
          end

          RedisAdapter
        end
      end
    end

    def initialize(uri_string, scope)
      @uri = URI(uri_string)
      @scope = scope
    end

    def [](key)
      adapter[key.to_s]
    end

    def multi_read(*keys)
      adapter.multi_read(*keys)
    end

    def []=(key, value)
      adapter[key.to_s] = value
    end

    def keys
      all_keys = adapter.keys

      all_keys.reject { |k| k.start_with? "____" }
    end

    def length
      keys.length
    end

    def any?
      !empty?
    end

    def empty?
      adapter.empty?
    end

    def delete(*keys)
      adapter.delete(*keys)
    end

    def merge!(h2)
      h2.transform_keys!(&:to_s)
      adapter.merge!(h2)
    end

    def clear
      adapter.clear
    end

    def to_h
      multi_read(*keys).transform_keys!(&:to_sym)
    end

    def inspect
      reload.to_h.dup
    end

    # Bypass any cached values. Helpful when you have two instances
    # of the same store where one mutates data and the other needs to check
    # on the status of that data (i.e. endpoint tests)
    def reload
      @adapter = nil
      self
    end

    private

    attr_reader :uri, :scope

    def adapter
      @adapter ||= self.class.adapter_klass(uri).new uri, scope
    end
  end
end
