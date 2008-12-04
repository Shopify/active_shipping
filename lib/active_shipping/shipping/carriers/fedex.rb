module ActiveMerchant
  module Shipping
    class FedEx < Carrier
      cattr_reader :name
      @@name = "FedEx"
      
      TEST_URL = 'https://gatewaybeta.fedex.com/GatewayDC'
      LIVE_URL = ''
      
      USE_SSL = true
      
      CarrierCodes = {
        "fedex_ground" => "FDXG",
        "fedex_express" => "FDXE"
      }
      
      ServiceTypes = {
        "PRIORITYOVERNIGHT" => "FedEx Priority Overnight",
        "FEDEX2DAY" => "FedEx 2 Day",
        "STANDARDOVERNIGHT" => "FedEx Standard Overnight",
        "FIRSTOVERNIGHT" => "FedEx First Overnight",
        "FEDEXEXPRESSSAVER" => "FedEx Express Saver",
        "FEDEX1DAYFREIGHT" => "FedEx 1 Day Freight",
        "FEDEX2DAYFREIGHT" => "FedEx 2 Day Freight",
        "FEDEX3DAYFREIGHT" => "FedEx 3 Day Freight",
        "INTERNATIONALPRIORITY" => "FedEx International Priority",
        "INTERNATIONALECONOMY" => "FedEx International Economy",
        "INTERNATIONALFIRST" => "FedEx International First",
        "INTERNATIONALPRIORITYFREIGHT" => "FedEx International Priority Freight",
        "INTERNATIONALECONOMYFREIGHT" => "FedEx International Economy Freight",
        "GROUNDHOMEDELIVERY" => "FedEx Ground Home Delivery",
        "FEDEXGROUND" => "FedEx Ground",
        "INTERNATIONALGROUND" => "FedEx International Ground"
      }

      PackageTypes = {
        "fedex_envelope" => "FEDEXENVELOPE",
        "fedex_pak" => "FEDEXPAK",
        "fedex_box" => "FEDEXBOX",
        "fedex_tube" => "FEDEXTUBE",
        "fedex_10_kg_box" => "FEDEX10KGBOX",
        "fedex_25_kg_box" => "FEDEX25KGBOX",
        "your_packaging" => "YOURPACKAGING"
      }

      DropoffTypes = {
        'regular_pickup' => 'REGULARPICKUP',
        'request_courier' => 'REQUESTCOURIER',
        'dropbox' => 'DROPBOX',
        'business_service_center' => 'BUSINESSSERVICECENTER',
        'station' => 'STATION'
      }

      PaymentTypes = {
        'sender' => 'SENDER',
        'recipient' => 'RECIPIENT',
        'third_party' => 'THIRDPARTY',
        'collect' => 'COLLECT'
      }
      
      def requirements
        [:account_number, :meter_number]
      end
      
      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        
        ground_rate_request = build_rate_request(origin, destination, packages, CarrierCodes['fedex_ground'], options)
        express_rate_request = build_rate_request(origin, destination, packages, CarrierCodes['fedex_express'], options)
        
        ground_response = ''
        express_response = ''
        
        t1 = Thread.new { ground_response = commit(save_request(ground_rate_request), (options[:test] || false)) }
        t2 = Thread.new { express_response = commit(save_request(express_rate_request), (options[:test] || false)) }
        
        t1.join
        t2.join
        parse_rate_response(origin, destination, packages, ground_response, express_response, options)
      end
      
      
      protected
      def build_rate_request(origin, destination, packages, carrier_code, options={})
        imperial = ['US','LR','MM'].include?(origin.country_code(:alpha2))
        total_weight = 0.0;
        packages.each do |package|
          total_weight += ((imperial ? package.lbs : package.kgs).to_f*1000).round/1000.0
        end
        
        
        xml_request = XmlNode.new('FDXRateAvailableServicesRequest', 'xmlns:api' => 'http://www.fedex.com/fsmapi', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXRateAvailableServicesRequest.xsd') do |root_node|
          root_node << build_request_header(carrier_code)
          root_node << XmlNode.new('ShipDate', @options[:ship_date] || Time.now.strftime("%Y-%m-%d"))
          root_node << XmlNode.new('DropoffType', @options[:dropoff_type] || DropoffTypes['regular_pickup'])
          root_node << XmlNode.new('Packaging', @options[:packaging] || PackageTypes['your_packaging'])
          root_node << XmlNode.new('WeightUnits', imperial ? 'LBS' : 'KGS')
          root_node << XmlNode.new('Weight', [total_weight, 0.1].max)
          root_node << XmlNode.new('ListRate', @options[:list_rate] || 'false')
          root_node << build_location_node('OriginAddress', origin)
          root_node << build_location_node('DestinationAddress', destination)
          root_node << XmlNode.new('Payment') do |payment_node|
            payment_node << XmlNode.new('PayorType', PaymentTypes[options[:payment_type] || 'sender'])
          end
          root_node << XmlNode.new('PackageCount', packages.count.to_s)
        end
        xml_request.to_xml
      end
      
      def build_request_header(carrier_code)
        xml_request = XmlNode.new('RequestHeader') do |access_request|
          access_request << XmlNode.new('AccountNumber', @options[:account_number])
          access_request << XmlNode.new('MeterNumber', @options[:meter_number])
          access_request << XmlNode.new('CarrierCode', carrier_code)
        end
        xml_request
      end
      
      def build_location_node(name, location)
        location_node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('StateOrProvinceCode', location.state)
          xml_node << XmlNode.new('PostalCode', location.postal_code)
          xml_node << XmlNode.new("CountryCode", location.country_code(:alpha2)) unless location.country_code(:alpha2).blank?
        end
      end
      
      def parse_rate_response(origin, destination, packages, ground_response, express_response, options)
        rates = []
        rate_estimates = []
        success, message = nil
        entries = []
        
        [ground_response, express_response].each do |response|
          xml_hash = Hash.from_xml(response)['FDXRateAvailableServicesReply']
          success = response_hash_success?(xml_hash)
          message = response_hash_message(xml_hash)
          if success
            entries << xml_hash['Entry']
            entries.flatten!
          end
        end
        
        entries.each do |rated_shipment|
          rate_estimates << RateEstimate.new(origin, destination, @@name,
                              ServiceTypes[rated_shipment['Service']],
                              :total_price => rated_shipment['EstimatedCharges']['DiscountedCharges']['NetCharge'].to_f,
                              :currency => rated_shipment['EstimatedCharges']['CurrencyCode'],
                              :packages => packages)
        end
        
        RateResponse.new(success, message, {}, :rates => rate_estimates)
      end
      
      def response_hash_success?(xml_hash)
        ! xml_hash['Error'] && ! xml_hash['SoftError']
      end
      
      def response_hash_message(xml_hash)
        response_hash_success?(xml_hash) ? '' : 'broke' #"FedEx Error Code: #{xml_hash['Error']['Code'] || xml_hash['SoftError']['Code']}: #{xml_hash['Error']['Message'] || xml_hash['SoftError']['Message']}"
      end
      
      def commit(request, test = false)
        uri = URI.parse(test ? TEST_URL : LIVE_URL)
        http = Net::HTTP.new uri.host, uri.port
        if USE_SSL
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        response = http.post(uri.path, request.gsub("\n",''))
        response.body
      end
    
    end
  end
end
