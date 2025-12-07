require "socket"

module Specwrk
  class IPC
    attr_reader :parent_socket, :child_socket

    def self.from_child_fd(fd, parent_pid:)
      new(
        parent_pid: parent_pid,
        child_socket: UNIXSocket.for_fd(fd)
      )
    end

    def initialize(parent_pid: Process.pid, parent_socket: nil, child_socket: nil)
      @parent_pid = parent_pid

      @parent_socket, @child_socket = parent_socket, child_socket
      @parent_socket, @child_socket = UNIXSocket.pair if @parent_socket.nil? && @child_socket.nil?
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

    attr_reader :parent_pid

    def socket
      child? ? child_socket : parent_socket
    end

    def child?
      Process.pid != parent_pid
    end
  end
end
