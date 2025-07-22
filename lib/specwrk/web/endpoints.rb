# frozen_string_literal: true

require "json"

module Specwrk
  class Web
    module Endpoints
      class Base
        attr_reader :pending_queue, :processing_queue, :completed_queue, :workers, :started_at

        def initialize(request)
          @request = request
        end

        def response
          datastore.with_lock do |db|
            @started_at = if db[:started_at]
              Time.parse(db[:started_at])
            else
              db[:started_at] = Time.now
            end

            @pending_queue = PendingQueue.new.merge!(db[:pending] || {})
            @processing_queue = Queue.new.merge!(db[:processing] || {})
            @completed_queue = CompletedQueue.new.merge!(db[:completed] || {})
            @workers = db[:workers] ||= {}

            worker[:first_seen_at] ||= Time.now
            worker[:last_seen_at] = Time.now

            with_response.tap do
              db[:pending] = pending_queue.to_h
              db[:processing] = processing_queue.to_h
              db[:completed] = completed_queue.to_h
              db[:workers] = workers.to_h
            end
          end
        end

        def with_response
          not_found
        end

        private

        attr_reader :request

        def not_found
          [404, {"Content-Type" => "text/plain"}, ["This is not the path you're looking for, 'ol chap..."]]
        end

        def ok
          [200, {"Content-Type" => "text/plain"}, ["OK, 'ol chap"]]
        end

        def payload
          @payload ||= JSON.parse(body, symbolize_names: true)
        end

        def body
          @body ||= request.body.read
        end

        def worker
          workers[request.get_header("HTTP_X_SPECWRK_ID")] ||= {}
        end

        def run_id
          request.get_header("HTTP_X_SPECWRK_RUN")
        end

        def run_report_file_path
          @run_report_file_path ||= File.join(ENV["SPECWRK_OUT"], run_id, "#{started_at.strftime("%Y%m%dT%H%M%S")}-report.json").to_s
        end

        def datastore
          Web.datastore[File.join(ENV["SPECWRK_OUT"], run_id, "queues.json").to_s]
        end
      end

      # Base default response is 404
      NotFound = Class.new(Base)

      class Health < Base
        def with_response
          [200, {}, []]
        end
      end

      class Heartbeat < Base
        def with_response
          ok
        end
      end

      class Seed < Base
        def with_response
          if ENV["SPECWRK_SRV_SINGLE_SEED_PER_RUN"].nil? || pending_queue.length.zero?
            examples = payload.map { |hash| [hash[:id], hash] }.to_h
            pending_queue.merge_with_previous_run_times!(examples)
          end

          ok
        end
      end

      class Complete < Base
        def with_response
          payload.each do |example|
            next unless processing_queue.delete(example[:id].to_sym)
            completed_queue[example[:id].to_sym] = example
          end

          if pending_queue.length.zero? && processing_queue.length.zero? && completed_queue.length.positive? && ENV["SPECWRK_OUT"]
            completed_queue.dump_and_write(run_report_file_path)
            FileUtils.ln_sf(run_report_file_path, File.join(ENV["SPECWRK_OUT"], "report.json"))
          end

          ok
        end
      end

      class Pop < Base
        def with_response
          @examples = pending_queue.shift_bucket

          @examples.each do |example|
            processing_queue[example[:id]] = example
          end

          if @examples.length.positive?
            [200, {"Content-Type" => "application/json"}, [JSON.generate(@examples)]]
          elsif pending_queue.length.zero? && processing_queue.length.zero? && completed_queue.length.zero?
            [204, {"Content-Type" => "text/plain"}, ["Waiting for sample to be seeded."]]
          elsif completed_queue.length.positive? && processing_queue.length.zero?
            [410, {"Content-Type" => "text/plain"}, ["That's a good lad. Run along now and go home."]]
          else
            not_found
          end
        end
      end

      class Report < Base
        def with_response
          if data
            [200, {"Content-Type" => "application/json"}, [data]]
          else
            [404, {"Content-Type" => "text/plain"}, ["Unable to report on run #{run_id}; no file matching #{"*-report-#{run_id}.json"}"]]
          end
        end

        private

        def data
          return @data if defined? @data

          return unless most_recent_run_report_file
          return unless File.exist?(most_recent_run_report_file)

          @data = File.open(most_recent_run_report_file, "r") do |file|
            file.flock(File::LOCK_SH)
            file.read
          end
        end

        def most_recent_run_report_file
          @most_recent_run_report_file ||= Dir.glob(File.join(ENV["SPECWRK_OUT"], run_id, "*-report.json")).last
        end
      end

      class Shutdown < Base
        def with_response
          interupt! if ENV["SPECWRK_SRV_SINGLE_RUN"]

          [200, {"Content-Type" => "text/plain"}, ["✌️"]]
        end

        def interupt!
          Thread.new do
            # give the socket a moment to flush the response
            sleep 0.2
            Process.kill("INT", Process.pid)
          end
        end
      end
    end
  end
end
