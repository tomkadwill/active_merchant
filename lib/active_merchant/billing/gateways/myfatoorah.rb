module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class MyfatoorahGateway < Gateway
      self.test_url = 'https://test.myfatoorah.com/pg/PayGatewayService.asmx?op=PaymentRequest'
      self.live_url = 'https://example.com/live'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]

      self.homepage_url = 'http://www.example.net/'
      self.display_name = 'New Gateway'

      STANDARD_ERROR_CODE_MAPPING = {}

      def initialize(options={})
        #TODO: fix this
        # requires!(options, :some_credential, :another_credential)
        super
      end

      def purchase(money, payment, options={})
        post = {}
        # TODO: fix this
        # add_invoice(post, money, options)
        # add_payment(post, payment)
        # add_address(post, payment, options)
        # add_customer_data(post, options)

        # request = build_xml_request do |doc|
        #   add_authentication(doc)
        #   doc.sale(transaction_attributes(options)) do
        #     add_auth_purchase_params(doc, money, payment_method, options)
        #   end
        # end

        commit(:sale, post)


        # commit('sale', post)
      end

      def authorize(money, payment, options={})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit('authonly', post)
      end

      def capture(money, authorization, options={})
        commit('capture', post)
      end

      def refund(money, authorization, options={})
        commit('refund', post)
      end

      def void(authorization, options={})
        commit('void', post)
      end

      def verify(credit_card, options={})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        transcript
      end

      private

      def add_customer_data(post, options)
      end

      def add_address(post, creditcard, options)
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || currency(money))
      end

      def add_payment(post, payment)
      end

      def parse(body)
        # TODO: parse the XML and then move backwards to remove the hardcoding
        body
      end

      def commit(action, parameters)
        url = (test? ? test_url : live_url)
        headers = {
          "Content-Type" => 'application/soap+xml; charset=utf-8'
        }
        response = parse(ssl_post(url, post_data(action, parameters), headers))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: response["some_avs_response_key"]),
          cvv_result: CVVResult.new(response["some_cvv_response_key"]),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        # TODO: fix this
        true
      end

      def message_from(response)
        # TODO: fix this
        true
      end

      def authorization_from(response)
        # TODO: fix this
        true
      end

      def post_data(action, parameters = {})
        # TODO: fix this
        <<-EOF
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
      end

      def error_code_from(response)
        unless success_from(response)
          # TODO: lookup error code for this response
        end
      end
    end
  end
end
