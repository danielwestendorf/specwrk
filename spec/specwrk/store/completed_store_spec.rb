# frozen_string_literal: true

require "securerandom"

require "specwrk/store/completed_store"

RSpec.describe Specwrk::CompletedStore do
  let(:uri_string) { "file://#{Dir.tmpdir}" }
  let(:scope) { SecureRandom.uuid }

  let(:instance) { described_class.new(uri_string, scope) }

  before { instance.clear }

  describe "#dump" do
    subject { instance.dump }

    let(:example_1) do
      {
        id: "./spec/specwrk/worker/progress_formatter_spec.rb[1:1:1]",
        status: "passed",
        file_path: "./spec/specwrk/worker/progress_formatter_spec.rb",
        started_at: "2025-06-26T09:20:58.444542-06:00",
        finished_at: "2025-06-26T09:20:58.444706-06:00",
        run_time: 0.000164
      }
    end
    let(:example_2) do
      {
        id: "./spec/specwrk/worker/progress_formatter_spec.rb[1:1:2]",
        status: "failed",
        file_path: "./spec/specwrk/worker/progress_formatter_spec.rb",
        started_at: "2025-06-26T09:20:58.444542-06:00",
        finished_at: "2025-06-26T09:20:58.444706-06:00",
        run_time: 0.000164
      }
    end
    let(:example_3) do
      {
        id: "./spec/specwrk/web/endpoints_spec.rb[1:4:3:1]",
        status: "pending",
        file_path: "./spec/specwrk/web/endpoints_spec.rb",
        started_at: "2025-06-26T09:20:58.448618-06:00",
        finished_at: "2025-06-26T09:20:58.456148-06:00",
        run_time: 0.00753
      }
    end
    let(:example_4) do
      {
        id: "./spec/specwrk_spec.rb[1:1]",
        status: "passed",
        file_path: "./spec/specwrk_spec.rb",
        started_at: "2025-06-26T09:20:58.434063-06:00",
        finished_at: "2025-06-26T09:20:58.434257-06:00",
        run_time: 0.000194
      }
    end

    before do
      instance.merge!(a: example_1, b: example_2, c: example_3, d: example_4)
    end

    it "dumps the data to a JSON file" do
      expect(subject).to eq({
        examples: {
          example_1[:id] => example_1,
          example_2[:id] => example_2,
          example_3[:id] => example_3,
          example_4[:id] => example_4
        },
        file_totals: {
          "./spec/specwrk/web/endpoints_spec.rb" => 0.00753,
          "./spec/specwrk/worker/progress_formatter_spec.rb" => 0.000328,
          "./spec/specwrk_spec.rb" => 0.000194
        },
        meta: {
          average_run_time: 0.002013,
          first_started_at: "2025-06-26T09:20:58.434063-06:00",
          last_finished_at: "2025-06-26T09:20:58.456148-06:00",
          passes: 2,
          failures: 1,
          pending: 1,
          total_run_time: 0.008052
        }
      })
    end
  end
end
