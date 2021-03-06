require 'pp'
require 'net/http'

module Lightspeed
  class Request
    attr_accessor :raw_request, :bucket_max, :bucket_level

    SECONDS_TO_WAIT_WHEN_THROTTLED = 60 # API requirements.

    class << self
      attr_writer :verbose
    end

    def self.verbose?
      !! @verbose
    end

    def self.base_host
      "api.merchantos.com"
    end

    def self.base_path
      "/API"
    end

    def initialize(client, method: nil, path: nil, params: nil, body: nil)
      @method = method
      @params = params
      @path = path
      @bucket_max = Float::INFINITY
      @bucket_level = 0
      @http = Net::HTTP.new(self.class.base_host, 443)
      @http.use_ssl = true
      @raw_request = request_class.new(uri)
      @raw_request.body = body if body
      @raw_request.set_form_data(@params) if @params && @method != :get
      @client = client
      set_authorization_header
    end

    def set_authorization_header
      @raw_request["Authorization"] = "Bearer #{@client.oauth_token}" if @client.oauth_token
    end

    def perform_raw
      response = @http.request(raw_request)
      extract_rate_limits(response)
      if response.code == "200"
        handle_success(response)
      else
        handle_error(response)
      end
    end

    def perform
      perform_raw
    rescue Lightspeed::Error::Throttled
      retry_throttled_request
    rescue Lightspeed::Error::Unauthorized
      @client.refresh_oauth_token
      set_authorization_header
      perform_raw
    end

    private

    def handle_success(response)
      json = Yajl::Parser.parse(response.body)
      pp json if self.class.verbose?
      json
    end

    def retry_throttled_request
      puts 'retrying throttled request after 60s.' if self.class.verbose?
      sleep SECONDS_TO_WAIT_WHEN_THROTTLED
      perform
    end

    def handle_error(response)
      data = Yajl::Parser.parse(response.body)
      error = case response.code.to_s
      when '400' then Lightspeed::Error::BadRequest
      when '401' then Lightspeed::Error::Unauthorized
      when '403' then Lightspeed::Error::NotAuthorized
      when '404' then Lightspeed::Error::NotFound
      when '429' then Lightspeed::Error::Throttled
      when /5../ then Lightspeed::Error::InternalServerError
      else Lightspeed::Error
      end
      raise error, data["message"]
    end

    def extract_rate_limits(response)
      if bucket_headers = response["X-LS-API-Bucket-Level"]
        @bucket_level, @bucket_max = bucket_headers.split("/").map(&:to_f)
      end
    end

    def uri
      uri = self.class.base_path + @path
      uri += "?" + URI.encode_www_form(@params) if @params && @method == :get
      uri
    end

    def request_class
      case @method
      when :get then Net::HTTP::Get
      when :put then Net::HTTP::Put
      when :post then Net::HTTP::Post
      when :delete then Net::HTTP::Delete
      end
    end

  end
end
