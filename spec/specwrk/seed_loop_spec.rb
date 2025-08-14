# frozen_string_literal: true

require "specwrk/seed_loop"

RSpec.describe Specwrk::SeedLoop do
  describe ".loop!" do
    let(:ipc) { instance_double("IPC", read: nil, write: nil) }

    let(:client_dbl) { instance_double(Specwrk::Client, seed: nil, close: nil) }

    before do
      allow(Specwrk::Client).to receive(:wait_for_server!)
      allow(Specwrk::Client).to receive(:new).and_return(client_dbl)
    end

    let(:list_examples_dbl) { instance_double(Specwrk::ListExamples, examples: examples) }
    let(:examples) { %w[spec/a_spec.rb:1 spec/b_spec.rb:1] }

    before do
      allow(Specwrk::ListExamples).to receive(:new)
        .with(%w[spec/a_spec.rb spec/b_spec.rb])
        .and_return(list_examples_dbl)
    end

    context "with a single batch of files" do
      before do
        allow(Specwrk).to receive(:force_quit).and_return(false, true) # run once, then break
        allow(ipc).to receive(:read).and_return("spec/a_spec.rb spec/b_spec.rb")
        allow(ipc).to receive(:write)
      end

      it "waits for the server, seeds parsed examples, closes client, and writes the count" do
        expect(Specwrk::Client).to receive(:wait_for_server!).once
        expect(Specwrk::ListExamples).to receive(:new).with(%w[spec/a_spec.rb spec/b_spec.rb])
        expect(client_dbl).to receive(:seed).with(examples, 0)
        expect(client_dbl).to receive(:close)
        expect(ipc).to receive(:write).with(2)

        described_class.loop!(ipc)
      end
    end

    context "when ipc.read returns nil first" do
      before do
        allow(Specwrk).to receive(:force_quit).and_return(false, false, true)
        allow(ipc).to receive(:read).and_return(nil, "spec/only_spec.rb")
        allow(ipc).to receive(:write)

        one_examples = [{}]
        allow(Specwrk::ListExamples).to receive(:new)
          .with(%w[spec/only_spec.rb])
          .and_return(instance_double("Specwrk::ListExamples", examples: one_examples))

        allow(client_dbl).to receive(:seed)
        allow(client_dbl).to receive(:close)
      end

      it "skips the nil read and processes the next non-empty batch" do
        expect(client_dbl).to receive(:seed).once
        expect(ipc).to receive(:write).with(1)

        described_class.loop!(ipc)
      end
    end
  end
end
