require "socket"

module Specwrk
  class IPC
    def initialize
      @parent_pid = Process.pid

      @parent_socket, @child_socket = UNIXSocket.pair
    end

    def write(msg)
      socket.puts msg.to_s
    end

    def read
      IO.select([socket])

      data = socket.gets&.chomp
      return if data.nil? || data.length.zero? || data == "INT"

      data
    end

    private

    attr_reader :parent_pid, :parent_socket, :child_socket

    def socket
      child? ? child_socket : parent_socket
    end

    def child?
      Process.pid != parent_pid
    end
  end
end
