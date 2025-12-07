# frozen_string_literal: true

require "specwrk/ipc"

RSpec.describe Specwrk::IPC do
  let(:instance) { described_class.new }

  after do
    [instance.parent_socket, instance.child_socket].each do |socket|
      socket.close unless socket.closed?
    end
  end

  describe "communication" do
    let(:parent_pid) { 42 }
    let(:child_pid) { 24 }

    it "selects the correct socket based on pid" do
      expect(Process).to receive(:pid)
        .and_return(parent_pid)
        .twice

      instance.write("ping")

      expect(Process).to receive(:pid)
        .and_return(child_pid)
        .exactly(3)

      expect(instance.read).to eq("ping")

      instance.write("pong")

      expect(Process).to receive(:pid)
        .and_return(parent_pid)
        .exactly(3)

      expect(instance.read).to eq("pong")

      instance.write nil

      expect(Process).to receive(:pid)
        .and_return(child_pid)
        .exactly(2)

      expect(instance.read).to eq(nil)

      expect(Process).to receive(:pid)
        .and_return(parent_pid)
        .once

      instance.write "INT"

      expect(Process).to receive(:pid)
        .and_return(child_pid)
        .exactly(2)

      expect(instance.read).to eq(nil)
    end
  end

  describe ".from_child_fd" do
    it "rehydrates a child socket and communicates with the parent socket" do
      parent_pid = 42
      child_pid = 24
      parent_ipc = described_class.new(parent_pid: parent_pid)
      child_ipc = described_class.from_child_fd(parent_ipc.child_socket.fileno, parent_pid: parent_pid)

      allow(Process).to receive(:pid).and_return(parent_pid)
      parent_ipc.write("ping")

      allow(Process).to receive(:pid).and_return(child_pid)
      expect(child_ipc.read).to eq("ping")
      child_ipc.write("pong")

      allow(Process).to receive(:pid).and_return(parent_pid)
      expect(parent_ipc.read).to eq("pong")
    ensure
      [parent_ipc.parent_socket, parent_ipc.child_socket].each do |socket|
        socket.close unless socket.closed?
      end
    end

    it "respects provided sockets without creating a new pair" do
      parent_socket, child_socket = UNIXSocket.pair
      ipc = described_class.new(parent_socket: parent_socket, child_socket: child_socket)

      expect(ipc.parent_socket).to eq(parent_socket)
      expect(ipc.child_socket).to eq(child_socket)
    ensure
      [parent_socket, child_socket].each do |socket|
        socket.close unless socket.closed?
      end
    end
  end
end
