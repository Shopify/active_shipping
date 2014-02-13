require 'cgi'
require 'builder'

module ActiveMerchant
  module Shipping

    # Stamps.com integration for rating, tracking, address validation, and label generation
    # Integration ID can be requested from Stamps.com

    class Stamps < Carrier
      self.ssl_version = :SSLv3

      cattr_reader :name
      @@name = 'Stamps'

      attr_reader :last_swsim_method

      LIVE_URL = 'https://swsim.stamps.com/swsim/swsimv34.asmx'
      TEST_URL = 'https://swsim.testing.stamps.com/swsim/swsimv34.asmx'
      NAMESPACE = 'http://stamps.com/xml/namespace/2014/01/swsim/swsimv34'

      REQUIRED_OPTIONS = [:integration_id, :username, :password].freeze

      def account_info
        request = build_get_account_info_request
        response = commit(:GetAccountInfo, request)
      end

      def namespace
        NAMESPACE
      end

      def clear_authenticator
        @authenticator = nil
      end

      private

      def requirements
        REQUIRED_OPTIONS
      end

      def save_swsim_method(swsim_method)
        @last_swsim_method = swsim_method
      end

      def authenticator
        get_authenticator unless @authenticator
        @authenticator
      end

      def renew_authenticator(request)
        old_authenticator = authenticator
        clear_authenticator
        request.sub(old_authenticator, authenticator)
      end

      def get_authenticator
        request = build_authenticate_user_request
        response = commit(:AuthenticateUser, request)
      end

      def build_header
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.soap(:Envelope, {
                   'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                   'xmlns:xsi'  => 'http://www.w3.org/2001/XMLSchema-instance',
                   'xmlns:xsd'  => 'http://www.w3.org/2001/XMLSchema',
                   'xmlns:tns'  => 'http://stamps.com/xml/namespace/2014/01/swsim/swsimv34'
                 }) do
          xml.soap :Body do
            yield(xml)
          end
        end
      end

      def build_authenticate_user_request
        build_header do |xml|
          xml.tns :AuthenticateUser do
            xml.tns :Credentials do
              xml.tns(:IntegrationID, @options[:integration_id])
              xml.tns(:Username, @options[:username])
              xml.tns(:Password, @options[:password])
            end
          end
        end
      end

      def build_get_account_info_request
        build_header do |xml|
          xml.tns :GetAccountInfo do
            xml.tns(:Authenticator, authenticator)
          end
        end
      end

      def commit(swsim_method, request)
        save_request(request)
        save_swsim_method(swsim_method)
        parse(ssl_post(request_url, request, 'Content-Type' => 'text/xml', 'SOAPAction' => soap_action(swsim_method)))
      rescue ActiveMerchant::ResponseError => e
        parse(e.response.body)
      end

      def request_url
        test_mode? ? TEST_URL : LIVE_URL
      end

      def soap_action(method)
        [NAMESPACE, method].join('/')
      end

      def parse(xml)
        response_options = {}
        response_options[:xml] = xml
        response_options[:request] = last_request
        response_options[:test] = test_mode?

        document = REXML::Document.new(xml)
        child_element = document.get_elements('//soap:Body/*').first
        parse_method = 'parse_' + child_element.name.underscore
        if respond_to?(parse_method, true)
          send(parse_method, child_element, response_options)
        else
          Response.new(false, "Unknown response object #{child_element.name}", response_options)
        end
      end

      def parse_fault(fault, response_options)
        @authenticator = fault.get_text('detail/authenticator').value if fault.get_text('detail/authenticator')

        error_code = if fault.elements['detail/stamps_exception']
          fault.elements['detail/stamps_exception'].attributes['code']
        elsif fault.elements['detail/sdcerror']
          fault.elements['detail/sdcerror'].attributes['code']
        else
          nil
        end

        # Renew the Authenticator if it has expired and retry  the request
        if error_code and error_code.downcase == '002b0202'
          request = renew_authenticator(last_request)
          commit(last_swsim_method, request)
        else
          raise ResponseError.new(fault.get_text('faultstring').to_s)
        end
      end

      def parse_authenticate_user_response(authenticate_user, response_options)
        parse_authenticator(authenticate_user)
      end

      def parse_authenticator(response)
        @authenticator = response.get_text('Authenticator').value
      end

      def parse_get_account_info_response(account_info_response, response_options)
        parse_authenticator(account_info_response)

        account_info = account_info_response.elements['AccountInfo']
        response_options[:customer_id]         = account_info.get_text('CustomerID').to_s
        response_options[:meter_number]        = account_info.get_text('MeterNumber').to_s
        response_options[:user_id]             = account_info.get_text('UserID').to_s
        response_options[:max_postage_balance] = account_info.get_text('MaxPostageBalance').to_s
        response_options[:lpo_city]            = account_info.get_text('LPOCity').to_s
        response_options[:lpo_state]           = account_info.get_text('LPOState').to_s
        response_options[:lpo_zip]             = account_info.get_text('LPOZip').to_s

        postage_balance_node = account_info.elements['PostageBalance']
        response_options[:available_postage] = postage_balance_node.get_text('AvailablePostage').to_s
        response_options[:control_total]     = postage_balance_node.get_text('ControlTotal').to_s

        capabilities_node = account_info.elements['Capabilities']
        response_options[:can_print_shipping]         = capabilities_node.get_text('CanPrintShipping').to_s == 'true'
        response_options[:can_use_cost_codes]         = capabilities_node.get_text('CanUseCostCodes').to_s == 'true'
        response_options[:can_use_hidden_postage]     = capabilities_node.get_text('CanUseHiddenPostage').to_s == 'true'
        response_options[:can_purchase_sdc_insurance] = capabilities_node.get_text('CanPurchaseSDCInsurance').to_s == 'true'
        response_options[:can_print_memo]             = capabilities_node.get_text('CanPrintMemoOnShippingLabel').to_s == 'true'
        response_options[:can_print_international]    = capabilities_node.get_text('CanPrintInternational').to_s == 'true'
        response_options[:can_purchase_postage]       = capabilities_node.get_text('CanPurchasePostage').to_s == 'true'
        response_options[:can_edit_cost_codes]        = capabilities_node.get_text('CanEditCostCodes').to_s == 'true'
        response_options[:must_use_cost_codes]        = capabilities_node.get_text('MustUseCostCodes').to_s == 'true'
        response_options[:can_view_online_reports]    = capabilities_node.get_text('CanViewOnlineReports').to_s == 'true'
        response_options[:per_print_limit]            = capabilities_node.get_text('PerPrintLimit').to_s

        StampsAccountInfoResponse.new(true, '', {}, response_options)
      end
    end

    class StampsAccountInfoResponse < Response
      attr_reader :customer_id, :meter_number, :user_id, :available_postage, :control_total, :max_postage_balance, :lpo
      attr_reader :can_print_shipping, :can_use_cost_codes, :can_use_hidden_postage, :can_purchase_sdc_insurance, :can_print_international
      attr_reader :can_print_memo, :can_purchase_postage, :can_edit_cost_codes, :must_use_cost_codes, :can_view_online_reports, :per_print_limit

      alias_method :can_print_shipping?, :can_print_shipping
      alias_method :can_use_cost_codes?, :can_use_cost_codes
      alias_method :can_use_hidden_postage?, :can_use_hidden_postage
      alias_method :can_purchase_sdc_insurance?, :can_purchase_sdc_insurance
      alias_method :can_print_international?, :can_print_international
      alias_method :can_print_memo?, :can_print_memo
      alias_method :can_purchase_postage?, :can_purchase_postage
      alias_method :can_edit_cost_codes?, :can_edit_cost_codes
      alias_method :must_use_cost_codes?, :must_use_cost_codes
      alias_method :can_view_online_reports?, :can_view_online_reports

      def initialize(success, message, params = {}, options = {})
        super
        @customer_id = options[:customer_id]
        @meter_number = options[:meter_number]
        @user_id = options[:user_id]
        @available_postage = options[:available_postage]
        @control_total = options[:control_total]
        @max_postage_balance = options[:max_postage_balance]
        @lpo = Location.new(
          city: options[:lpo_city],
          state: options[:lpo_state],
          zip: options[:lpo_zip]
        )
        @can_print_shipping         = options[:can_print_shipping]
        @can_use_cost_codes         = options[:can_use_cost_codes]
        @can_use_hidden_postage     = options[:can_use_hidden_postage]
        @can_purchase_sdc_insurance = options[:can_purchase_sdc_insurance]
        @can_print_memo             = options[:can_print_memo]
        @can_print_international    = options[:can_print_international]
        @can_purchase_postage       = options[:can_purchase_postage]
        @can_edit_cost_codes        = options[:can_edit_cost_codes]
        @must_use_cost_codes        = options[:must_use_cost_codes]
        @can_view_online_reports    = options[:can_view_online_reports]
        @per_print_limit            = options[:per_print_limit]
      end
    end
  end
end
