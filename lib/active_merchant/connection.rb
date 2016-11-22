require 'uri'
require 'net/http'
require 'net/https'
require 'benchmark'

module ActiveMerchant
  class Connection
    include NetworkConnectionRetries

    MAX_RETRIES = 3
    OPEN_TIMEOUT = 60
    READ_TIMEOUT = 60
    VERIFY_PEER = true
    CA_FILE = File.expand_path('../certs/cacert.pem', File.dirname(__FILE__))
    CA_PATH = nil
    RETRY_SAFE = false
    RUBY_184_POST_HEADERS = { "Content-Type" => "application/x-www-form-urlencoded" }

    attr_accessor :endpoint
    attr_accessor :open_timeout
    attr_accessor :read_timeout
    attr_accessor :verify_peer
    attr_accessor :ssl_version
    attr_accessor :ca_file
    attr_accessor :ca_path
    attr_accessor :pem
    attr_accessor :pem_password
    attr_accessor :wiredump_device
    attr_accessor :logger
    attr_accessor :tag
    attr_accessor :ignore_http_status
    attr_accessor :max_retries
    attr_accessor :proxy_address
    attr_accessor :proxy_port

    def initialize(endpoint)
      @endpoint     = endpoint.is_a?(URI) ? endpoint : URI.parse(endpoint)
      @open_timeout = OPEN_TIMEOUT
      @read_timeout = READ_TIMEOUT
      @retry_safe   = RETRY_SAFE
      @verify_peer  = VERIFY_PEER
      @ca_file      = CA_FILE
      @ca_path      = CA_PATH
      @max_retries  = MAX_RETRIES
      @ignore_http_status = false
      @ssl_version = nil
      @proxy_address = nil
      @proxy_port = nil
    end

    def request(method, body, headers = {})
      request_start = Time.now.to_f

      retry_exceptions(:max_retries => max_retries, :logger => logger, :tag => tag) do
        begin
          info "connection_http_method=#{method.to_s.upcase} connection_uri=#{endpoint}", tag

          result = nil

          realtime = Benchmark.realtime do
            result = case method
            when :get
              raise ArgumentError, "GET requests do not support a request body" if body
              http.get(endpoint.request_uri, headers)
            when :post
              debug body

              # TODO: fix this
              url = URI("https://test.myfatoorah.com/pg/PayGatewayService.asmx?op=PaymentRequest" ) #SOAP url to be called from ruby client, change this url for other calls
              http = Net::HTTP.new(url.host, url.port) #http post start
              http.use_ssl = true
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE #setting ssl request
              header = { "Content-Type" => 'application/soap+xml; charset=utf-8' } #set headers, you can additional header attributes here as per requirement
              request = Net::HTTP::Post.new(url, header) #creating post request

              data = <<-EOF
              <?xml version="1.0" encoding="utf-8"?>
              <soap12:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap12="http://www.w3.org/2003/05/soap-envelope">
              <soap12:Body>
              <PaymentRequest xmlns="http://tempuri.org/">
              <req> <CustomerDC>
              <Name>string</Name> <Email>string</Email> <Mobile>string</Mobile> <Gender>string</Gender> <DOB>string</DOB> <civil_id>string</civil_id> <Area>string</Area> <Block>string</Block> <Street>string</Street> <Avenue>string</Avenue> <Building>string</Building> <Floor>string</Floor> <Apartment>string</Apartment>
              </CustomerDC> <MerchantDC>
              <merchant_code>999999</merchant_code> <merchant_username>testapi@myfatoorah.com</merchant_username> <merchant_password>E55D0</merchant_password> <merchant_ReferenceID>201454542102</merchant_ReferenceID> <ReturnURL>http://example.com</ReturnURL> <merchant_error_url>string</merchant_error_url> <udf1>string</udf1>
              <udf2>string</udf2> <udf3>string</udf3> <udf4>string</udf4> <udf5>string</udf5>
              </MerchantDC> <lstProductDC> <ProductDC>
              <product_name>example_product_name</product_name> <unitPrice>100.2</unitPrice>
              <qty>3</qty>
              MYFATOORAH
              </ProductDC> <ProductDC>
              <product_name>example_product_name_2</product_name> <unitPrice>200.50</unitPrice>
              <qty>4</qty>
              </ProductDC> </lstProductDC>
              </req> </PaymentRequest>
              </soap12:Body>
              </soap12:Envelope>
              EOF

              request.body = data #attaching data to post request for soap call
              response = http.request(request) #sending actual request
              response.read_body




              # http.post(endpoint.request_uri, body, RUBY_184_POST_HEADERS.merge(headers))
            when :put
              debug body
              http.put(endpoint.request_uri, body, headers)
            when :patch
              debug body
              http.patch(endpoint.request_uri, body, headers)
            when :delete
              # It's kind of ambiguous whether the RFC allows bodies
              # for DELETE requests. But Net::HTTP's delete method
              # very unambiguously does not.
              raise ArgumentError, "DELETE requests do not support a request body" if body
              http.delete(endpoint.request_uri, headers)
            else
              raise ArgumentError, "Unsupported request method #{method.to_s.upcase}"
            end
          end

          # TODO: put this back in
          # info "--> %d %s (%d %.4fs)" % [result.code, result.message, result.body ? result.body.length : 0, realtime], tag
          # debug result.body
          result
        end
      end

    ensure
      info "connection_request_total_time=%.4fs" % [Time.now.to_f - request_start], tag
    end

    private
    def http
      http = Net::HTTP.new(endpoint.host, endpoint.port, proxy_address, proxy_port)
      configure_debugging(http)
      configure_timeouts(http)
      configure_ssl(http)
      configure_cert(http)
      http
    end

    def configure_debugging(http)
      http.set_debug_output(wiredump_device)
    end

    def configure_timeouts(http)
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout
    end

    def configure_ssl(http)
      return unless endpoint.scheme == "https"

      http.use_ssl = true
      http.ssl_version = ssl_version if ssl_version

      if verify_peer
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file     = ca_file
        http.ca_path     = ca_path
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

    end

    def configure_cert(http)
      return if pem.blank?

      http.cert = OpenSSL::X509::Certificate.new(pem)

      if pem_password
        http.key = OpenSSL::PKey::RSA.new(pem, pem_password)
      else
        http.key = OpenSSL::PKey::RSA.new(pem)
      end
    end

    def handle_response(response)
      if @ignore_http_status then
        return response.body
      else
        case response.code.to_i
        when 200...300
          response.body
        else
          raise ResponseError.new(response)
        end
      end
    end

    def debug(message, tag = nil)
      log(:debug, message, tag)
    end

    def info(message, tag = nil)
      log(:info, message, tag)
    end

    def error(message, tag = nil)
      log(:error, message, tag)
    end

    def log(level, message, tag)
      message = "[#{tag}] #{message}" if tag
      logger.send(level, message) if logger
    end
  end
end
