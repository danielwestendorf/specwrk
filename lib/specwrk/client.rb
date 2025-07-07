# frozen_string_literal: true

require "uri"
require "net/http"
require "json"

module Specwrk
  class Client
    def self.connect?
      http = build_http
      http.start
      http.finish

      true
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      false
    end

    def self.build_http
      uri = URI(ENV.fetch("SPECWRK_SRV_URI", "http://localhost:5138"))
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = ENV.fetch("SPECWRK_TIMEOUT", "5").to_i
        http.read_timeout = ENV.fetch("SPECWRK_TIMEOUT", "5").to_i
        http.keep_alive_timeout = 300
      end
    end

    def self.wait_for_server!
      timeout = Time.now + ENV.fetch("SPECWRK_TIMEOUT", "5").to_i
      connected = false

      until connected || Time.now > timeout
        connected = connect?
        sleep 0.1 unless connected
      end

      raise Errno::ECONNREFUSED unless connected
    end

    attr_reader :last_request_at

    def initialize
      @mutex = Mutex.new
      @http = self.class.build_http
      @http.start
    end

    def close
      @mutex.synchronize { @http.finish }
    end

    def heartbeat
      response = get "/heartbeat"

      response.code == "200"
    end

    def stats
      response = get "/stats"

      if response.code == "200"
        JSON.parse(response.body, symbolize_names: true)
      else
        raise UnhandledResponseError.new("#{response.code}: #{response.body}")
      end
    end

    def shutdown
      response = delete "/shutdown"

      if response.code == "200"
        response.body
      else
        raise UnhandledResponseError.new("#{response.code}: #{response.body}")
      end
    end

    def fetch_examples
      response = post "/pop"

      case response.code
      when "200"
        JSON.parse(response.body, symbolize_names: true)
      when "404"
        raise NoMoreExamplesError
      when "410"
        raise CompletedAllExamplesError
      else
        raise UnhandledResponseError.new("#{response.code}: #{response.body}")
      end
    end

    def complete_examples(examples)
      response = post "/complete", body: examples.to_json

      (response.code == "200") ? true : UnhandledResponseError.new("#{response.code}: #{response.body}")
    end

    def seed(examples)
      response = post "/seed", body: examples.to_json

      (response.code == "200") ? true : UnhandledResponseError.new("#{response.code}: #{response.body}")
    end

    private

    def get(path, headers: default_headers, body: nil)
      request = Net::HTTP::Get.new(path, headers)
      request.body = body if body

      make_request(request)
    end

    def post(path, headers: default_headers, body: nil)
      request = Net::HTTP::Post.new(path, headers)
      request.body = body if body

      make_request(request)
    end

    def put(path, headers: default_headers, body: nil)
      request = Net::HTTP::Put.new(path, headers)
      request.body = body if body

      make_request(request)
    end

    def delete(path, headers: default_headers, body: nil)
      request = Net::HTTP::Delete.new(path, headers)
      request.body = body if body

      make_request(request)
    end

    def make_request(request)
      @mutex.synchronize do
        @last_request_at = Time.now
        @http.request(request)
      end
    end

    def default_headers
      @default_headers ||= {}.tap do |h|
        h["Authorization"] = "Bearer #{ENV["SPECWRK_SRV_KEY"]}" if ENV["SPECWRK_SRV_KEY"]
        h["X-Specwrk-Run"] = ENV["SPECWRK_RUN"] if ENV["SPECWRK_RUN"]
        h["Content-Type"] = "application/json"
      end
    end
  end
end
