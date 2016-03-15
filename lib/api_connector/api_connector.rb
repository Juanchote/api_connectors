# * Parent Connector for APIs
# * author: juanma <jm.rodulfo.salcedo@gmail.com>
module Connectors #:nodoc:
  # === Heading
  # This class has all the common logic from <b>api connectors</b>.
  class ApiConnector
    attr_reader :logger, :api_client_id, :api_domain, :api_mall_id,
      :api_domain_format, :api_headers_token, :connection_protocol,
      :headers, :code, :cookies, :cookie_jar, :request, :body

    def initialize(options = {}) #:notnew:
      options.symbolize_keys!

      #@logger = Logger.new "#{Rails.root}/log/#{self.class.to_s.demodulize.underscore}.log"
      #@logger.level = Rails.logger.level

      opts_to_vars(options)
    end

    # makes a GET request
    #
    # ==== Attributes
    #  * +hash+ - Hash of Parameters
    #  ** +endpoint+ - Url endpoint ex. /product/get (no need to specify the version)
    #  ** +args+ - Request arguments, (add headers key for extra headers options) ex. hash[:headers] = { 'content-type' => 'xml' }
    #  ** +params+ - Request parameters. ex. hash[:params] = { 'merchantId' => 'XXXXXX' }
    def get(hash={})
      hash.symbolize_keys!
      call(:get, hash[:endpoint], (hash[:args]||{}), hash[:params]||{})
    end

    def delete(hash={})
      hash.symbolize_keys!
      call(:delete, hash[:endpoint], (hash[:args]||{}), hash[:params]||{})
    end

    # makes a POST request
    #
    # ==== Attributes
    # * +hash+ - Hash of parameters
    # ** +endpoint+ - Url endpoint ex. /product/createOrUpdate
    # ** +args+ - Request arguments, (add headers key for extra headers options) ex. hash[:headers] = { 'content-type' => 'xml' }
    # * +payload+ - Data for the request ex. { merchantId: 'asdasdsadas', products: [{ ... },{ ...}...]}
    def post hash={}, payload
      raise 'Payload cannot be blank' if payload.nil? || payload.empty?

      hash.symbolize_keys!
      call(:post, hash[:endpoint], (hash[:args]||{}).merge({:method => :post}), payload)
    end

    # low level api for request (needed por PUT, PATCH & DELETE methods)
    #
    # ==== Attributes
    # * +endpoint+ - Url endpoint ex. /merchant/get
    # * +args+ - Request arguments, (add headers key for extra headers options) ex. { method: :get, headers: { 'content-type' => 'xml' } } (method key is needed, otherwise :get will be setted)
    # * +params+ - Request parameters / payload data
    def call method, endpoint, args={}, params
      raise "Endpoint can't be blank" unless endpoint
      raise "Method is missing" unless method

      url = (method == :get || method == :delete) ? url(endpoint,params) : url(endpoint)

      begin
        RestClient::Request.execute(method: method,
                                url: url,
                                headers: header(args[:headers]),
                                payload: params || {}
                               ) do |response, request, result|
                                 status = response.code == 200 ? :debug : :error
                                 #print(status, request, response.body)
                                 parse(response, endpoint)
                               end
      rescue RestClient::RequestTimeout
        { status: '400', message: "RestClient timeout" }
      end
    end

    def parse(response, endpoint = nil)
      @headers, @code, @cookies, @cookie_jar, @request, @body = response.headers, response.code, response.cookies, response.cookie_jar, response.request, response.body
      begin
        JSON.parse(response)
      rescue JSON::ParserError
        { status: '400', message: "RestClient failed to parse JSON: #{response}" }
      end
    end

    protected

    def opts_to_vars(opts)
      instance_eval do
        opts.each do |k, v|
          instance_variable_set("@#{k}".to_sym, v)
        end
      end
    end

    def header headers={}
      common_headers.merge({
        'X-Client-Id' => @x_person_id,
        'Content-Type' => @content_type || 'application/json',
        'Charset' => @charset || 'utf-8'
      }).merge(headers || {})
    end

    def url endpoint, args={}
      url_constructor endpoint, args
    end


    def print(status, request, response)
      status = :debug
      @logger.send(status,
                   "#{DateTime.now} "\
                   "- Request: #{request.inspect} "\
                   "- Response: #{response.force_encoding('utf-8')}"
                  )
    end

    def common_headers
      { 'X-Client-Id' => api_client_id }.merge(
        {"Authorization" => "Basic #{@api_headers_token}"}
      ) if @api_headers_token
    end

    def url_constructor endpoint, hash
      url = "#{@connection_protocol}://#{format(@api_domain)}/#{format(@prefix)}" << (@version ? "/#{@version}" : "") << "/#{format(endpoint)}"
      url << ("?#{parametrize(hash)}") unless hash.empty?
      url
    end

    def parametrize hash
      hash.map do |key,values|
        [values].flatten.map do |value|
          "#{key}=#{value}"
        end
      end.join('&')
    end

    def format string
      match_data = string.match(/\w+.+\w+/)
      match_data ? match_data[0] : ''
    end
  end
end
