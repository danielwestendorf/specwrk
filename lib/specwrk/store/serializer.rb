# frozen_string_literal: true

require "json"

module Specwrk
  class Store
    module Serializers
      module JSON
        module_function

        def adapter_name
          "json"
        end

        def dump(value)
          ::JSON.generate(value)
        end

        def load(payload)
          ::JSON.parse(payload, symbolize_names: true)
        end
      end

      module MessagePack
        def ensure_loaded!
          return if defined?(::MessagePack)

          require "msgpack"
        rescue LoadError
          raise LoadError, "Unable to use msgpack, gem not found. Add `gem 'msgpack' to your Gemfile and bundle install"
        end

        def adapter_name
          "msgpack"
        end

        def dump(value)
          packer.tap(&:clear)
            .tap { it.write(value) }
            .then(&:to_s)
        end

        def load(payload)
          unpacker.tap(&:reset)
            .tap { it.feed(payload) }
            .then { it.read }
        end

        def packer
          ensure_loaded!

          Thread.current[:__specwrk_msgpack_packer] ||= ::MessagePack::Packer.new
        end

        def unpacker
          ensure_loaded!

          Thread.current[:__specwrk_msgpack_unpacker] ||= ::MessagePack::Unpacker.new(symbolize_keys: true)
        end

        module_function :ensure_loaded!, :adapter_name, :dump, :load, :packer, :unpacker
      end
    end

    module Serializer
      module_function

      def resolve(name = ENV.fetch("SPECWRK_STORE_SERIALIZER", "json"))
        return name if name.respond_to?(:dump) && name.respond_to?(:load)

        case name.to_s.downcase
        when "", "json"
          Serializers::JSON
        when "msgpack", "messagepack"
          Serializers::MessagePack.tap(&:ensure_loaded!)
        else
          raise ArgumentError, "Unsupported serializer #{name.inspect}. Choose json or msgpack."
        end
      end
    end
  end
end
