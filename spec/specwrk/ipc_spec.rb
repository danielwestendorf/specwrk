# frozen_string_literal: true

require "specwrk/ipc"

RSpec.describe Specwrk::IPC do
  let(:instance) { described_class.new }

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
end
