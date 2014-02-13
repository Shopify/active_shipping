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

      PACKAGE = [
                 'Postcard',
                 'Letter',
                 'Large Envelope or Flat',
                 'Thick Envelope',
                 'Package',
                 'Flat Rate Box',
                 'Small Flat Rate Box',
                 'Large Flat Rate Box',
                 'Flat Rate Envelope',
                 'Flat Rate Padded Envelope',
                 'Large Package',
                 'Oversized Package',
                 'Regional Rate Box A',
                 'Regional Rate Box B',
                 'Regional Rate Box C',
                 'Legal Flat Rate Envelope'
                ].freeze

      US_POSSESSIONS = ["AS", "FM", "GU", "MH", "MP", "PW", "PR", "VI"]

      SERVICE_TYPES = {
        'US-FC'  => 'USPS First-Class Mail',
        'US-MM'  => 'USPS Media Mail',
        'US-PM'  => 'USPS Priority Mail',
        'US-BP'  => 'USPS BP',
        'US-LM'  => 'USPS LM',
        'US-XM'  => 'USPS Express Mail',
        'US-EMI' => 'USPS Express Mail International',
        'US-PMI' => 'USPS Priority Mail International',
        'US-FCI' => 'USPS First Class Mail International',
        'US-CM'  => 'USPS Critical Mail',
        'US-PS'  => 'USPS Parcel Select'
      }

      ADD_ONS = {
        'SC-A-HP'    => 'Hidden Postage',
        'SC-A-INS'   => 'Insurance',
        'SC-A-INSRM' => 'Insurance for Registered Mail',
        'US-A-CM'    => 'Certified Mail',
        'US-A-COD'   => 'Collect on Delivery',
        'US-A-COM'   => 'Certificate of Mailing',
        'US-A-DC'    => 'USPS Delivery Confirmation',
        'US-A-ESH'   => 'USPS Express - Sunday / Holiday Guaranteed',
        'US-A-INS'   => 'USPS Insurance',
        'US-A-NDW'   => 'USPS Express - No Delivery on Saturdays',
        'US-A-RD'    => 'Restricted Delivery',
        'US-A-REG'   => 'Registered Mail',
        'US-A-RR'    => 'Return Receipt Requested',
        'US-A-RRM'   => 'Return Receipt for Merchandise',
        'US-A-SC'    => 'USPS Signature Confirmation',
        'US-A-SH'    => 'Special Handling',
        'US-A-NND'   => 'Notice of non-delivery',
        'US-A-SR'    => 'Unknow Service Name SR',
        'US-A-RRE'   => 'Unknow Service Name RRE'
      }

      def account_info
        request = build_get_account_info_request
        response = commit(:GetAccountInfo, request)
      end

      def find_rates(origin, destination, package, options = {})
        origin = standardize_address(origin)
        destination = standardize_address(destination)

        request = build_rate_request(origin, destination, package, options)
        response = commit(:GetRates, request)
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

      def international?(address)
        ! (['US', nil] + US_POSSESSIONS).include?(address.country_code)
      end

      def standardize_address(address)
        if US_POSSESSIONS.include?(address.country_code)
          new_address = address.to_hash
          new_address[:province] = new_address[:country]
          new_address[:country] = 'US'
          Location.new(new_address)
        else
          address
        end
      end

      def domestic?(address)
        address.country_code(:alpha2) == 'US' || address.country_code(:alpha2).nil?
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

      def build_rate_request(origin, destination, package, options)
        build_header do |xml|
          xml.tns :GetRates do
            xml.tns(:Authenticator, authenticator)
            add_rate(xml, origin, destination, package, options)
          end
        end
      end

      def add_rate(xml, origin, destination, package, options)
        value = package.value ? '%.2f' % (package.value.to_f / 100) : nil
        options[:insured_value] ||= value
        options[:declared_value] ||= value if international?(destination)

        xml.tns :Rate do
          xml.tns(:FromZIPCode,       origin.postal_code) unless origin.postal_code.blank?
          xml.tns(:ToZIPCode,         destination.postal_code) unless destination.postal_code.blank?
          xml.tns(:ToCountry,         destination.country_code) unless destination.country_code.blank?
          xml.tns(:ServiceType,       options[:service]) unless options[:service].blank?
          xml.tns(:PrintLayout,       options[:print_layout]) unless options[:print_layout].blank?
          xml.tns(:WeightOz,          [package.ounces, 1].max)
          xml.tns(:PackageType,       options[:package_type] || 'Package')
          xml.tns(:Length,            package.inches(:length)) if package.inches(:length)
          xml.tns(:Width,             package.inches(:width)) if package.inches(:width)
          xml.tns(:Height,            package.inches(:height)) if package.inches(:height)
          xml.tns(:ShipDate,          options[:ship_date] || Date.today)
          xml.tns(:InsuredValue,      options[:insured_value]) unless options[:insured_value].blank?
          xml.tns(:CODValue,          options[:cod_value]) unless options[:cod_value].blank?
          xml.tns(:DeclaredValue,     options[:declared_value]) unless options[:declared_value].blank?

          machinable = if package.options.has_key?(:machinable)
            package.options[:machinable] ? true : false
          else
            USPS.package_machinable?(package)
          end

          xml.tns(:NonMachinable,     true) unless machinable

          xml.tns(:RectangularShaped, ! package.cylinder?)
          xml.tns(:GEMNotes,          options[:gem_notes]) unless options[:gem_notes].blank?

          add_ons = Array(options[:add_ons])
          unless add_ons.empty?
            xml.tns(:AddOns) do
              add_ons.each do |add_on|
                xml.tns(:AddOnV5) do
                  xml.tns(:AddOnType, add_on)
                end
              end
            end
          end

          xml.tns(:ToState,           destination.province) unless destination.province.blank?
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

      def parse_get_rates_response(get_rates, response_options)
        parse_authenticator(get_rates)

        response_options[:estimates] = get_rates.get_elements('Rates/Rate').map do |rate|
          parse_rate(rate)
        end

        RateResponse.new(true, '', {}, response_options)
      end

      def parse_rate(rate)
        rate_options = {}

        origin = Location.new(zip: rate.get_text('FromZIPCode').to_s)

        location_values = {}
        location_values[:zip]     = rate.get_text('ToZIPCode').to_s if rate.get_text('ToZIPCode')
        location_values[:country] = rate.get_text('ToCountry').to_s if rate.get_text('ToCountry')
        destination = Location.new(location_values)

        service_name = SERVICE_TYPES[rate.get_text('ServiceType').to_s]

        rate_options[:service_code]  = rate.get_text('ServiceType').to_s
        rate_options[:currency]      = 'USD'
        rate_options[:shipping_date] = Date.parse(rate.get_text('ShipDate').to_s)

        if delivery_days = rate.get_text('DeliverDays')
          delivery_days = delivery_days.to_s.split('-')
          rate_options[:delivery_range] = delivery_days.map { |day| rate_options[:shipping_date] + day.to_i.days }
        end

        rate_options[:total_price] = rate.get_text('Amount').to_s

        rate_options[:add_ons]     = parse_add_ons(rate)
        rate_options[:packages]    = parse_package(rate)

        add_ons = rate_options[:add_ons]
        if add_ons['SC-A-INS'] and add_ons['SC-A-INS'][:amount]
          rate_options[:insurance_price] = add_ons['SC-A-INS'][:amount]
        elsif add_ons['US-A-INS'] and add_ons['US-A-INS'][:amount]
          rate_options[:insurance_price] = add_ons['US-A-INS'][:amount]
        end

        StampsRateEstimate.new(origin, destination, @@name, service_name, rate_options)
      end

      def parse_add_ons(rate)
        add_ons = {}
        rate.get_elements('AddOns/AddOnV5').each do |add_on|
          add_on_type = add_on.get_text('AddOnType').to_s

          add_on_details = {}
          add_on_details[:missing_data] = add_on.get_text('MissingData').to_s if add_on.get_text('MissingData')
          add_on_details[:amount]       = add_on.get_text('Amount').to_s if add_on.get_text('Amount')

          prohibited_with = add_on.get_elements('ProhibitedWithAnyOf/AddOnTypeV5').map { |p| p.text }
          add_on_details[:prohibited_with] = prohibited_with unless prohibited_with.empty?

          add_ons[add_on_type] = add_on_details
        end

        add_ons
      end

      def parse_package(rate)
        weight = rate.get_text('WeightOz').to_s.to_f

        dimensions = ['Length', 'Width', 'Height'].map do |dim|
          rate.get_text(dim) ? rate.get_text(dim).to_s.to_f : nil
        end
        dimensions.compact!

        package_options = { units: :imperial }

        if value = rate.get_text('InsuredValue') || rate.get_text('DeclaredValue')
          package_options[:value] = value.to_s.to_f
          package_options[:currency] = 'USD'
        end

        Package.new(weight, dimensions, package_options)
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

    class StampsRateEstimate < RateEstimate
      attr_reader :add_ons

      def initialize(origin, destination, carrier, service_name, options={})
        super
        @add_ons = options[:add_ons]
      end

      def available_add_ons
        add_ons.keys
      end
    end
  end
end
