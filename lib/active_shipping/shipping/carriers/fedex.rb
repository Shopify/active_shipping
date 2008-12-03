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
        "FedEx Priority Overnight" => "PRIORITYOVERNIGHT",
        "FedEx 2 Day" => "FEDEX2DAY",
        "FedEx Standard Overnight" => "STANDARDOVERNIGHT",
        "FedEx First Overnight" => "FIRSTOVERNIGHT",
        "FedEx Express Saver" => "FEDEXEXPRESSSAVER",
        "FedEx 1 Day Freight" => "FEDEX1DAYFREIGHT",
        "FedEx 2 Day Freight" => "FEDEX2DAYFREIGHT",
        "FedEx 3 Day Freight" => "FEDEX3DAYFREIGHT",
        "FedEx International Priority" => "INTERNATIONALPRIORITY",
        "FedEx International Economy" => "INTERNATIONALECONOMY",
        "FedEx International First" => "INTERNATIONALFIRST",
        "FedEx International Priority Freight" => "INTERNATIONALPRIORITYFREIGHT",
        "FedEx International Economy Freight" => "INTERNATIONALECONOMYFREIGHT",
        "FedEx Ground Home Delivery" => "GROUNDHOMEDELIVERY",
        "FedEx Ground" => "FEDEXGROUND",
        "FedEx International Ground" => "INTERNATIONALGROUND"
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

      
      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        rate_request = build_rate_request(origin, destination, packages, options)
        response = commit(save_request(rate_request), (options[:test] || false))
        parse_rate_response(origin, destination, packages, response, options)
      end
      
      
      protected
      def build_rate_request(origin, destination, packages, options={})
        xml_request = XmlNode.new('FDXRateAvailableServicesRequest', 'xmlns:api' => 'http://www.fedex.com/fsmapi', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXRateAvailableServicesRequest.xsd') do |root_node|
          root_node << build_request_header(CarrierCodes[options[:carrier_code] || "fedex_ground"])
          # root_node << build_rate_options(packages)
          
          root_node << XmlNode.new('ShipDate', @options[:ship_date] || Time.now.strftime("%Y-%m-%d"))
          root_node << XmlNode.new('DropoffType', @options[:dropoff_type] || DropoffTypes['regular_pickup'])
          root_node << XmlNode.new('Packaging', @options[:packaging] || PackageTypes['your_packaging'])
          root_node << XmlNode.new('WeightUnits', @options[:weight_units] || 'LBS')
          root_node << XmlNode.new('Weight', '10.0')
          
          root_node << XmlNode.new('ListRate', 'false')
          
          
          
          root_node << build_location_node('OriginAddress', origin)
          root_node << build_location_node('DestinationAddress', destination)
          root_node << XmlNode.new('Payment') do |payment_node|
            payment_node << XmlNode.new('PayorType', PaymentTypes[options[:payment_type] || 'sender'])
          end
          root_node << XmlNode.new('PackageCount', packages.count.to_s)
          
        end
        puts xml_request.to_xml
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
          xml_node << XmlNode.new('StateOrProvinceCode', state_or_province(location))
          xml_node << XmlNode.new('PostalCode', zip_or_postal_code(location))
          xml_node << XmlNode.new("CountryCode", location.country_code(:alpha2)) unless location.country_code(:alpha2).blank?
        end
      end
      
      def parse_rate_response(origin, destination, packages, response, options)
        rates = []
        
        xml_hash = Hash.from_xml(response)['FDXRateAvailableServicesReply']
        success = response_hash_success?(xml_hash)
        message = response_hash_message(xml_hash)
        
        if success
          rate_estimates = []
          
          xml_hash['Entry'].each do |rated_shipment|
            rate_estimates << RateEstimate.new(origin, destination, @@name,
                                ServiceTypes.invert[rated_shipment['Service']],
                                :total_price => rated_shipment['EstimatedCharges']['DiscountedCharges']['NetCharge'].to_f,
                                :currency => rated_shipment['EstimatedCharges']['CurrencyCode'],
                                :packages => packages)
          end
        end
        RateResponse.new(success, message, xml_hash, :rates => rate_estimates, :xml => response, :request => last_request)
      end
      
      def response_hash_success?(xml_hash)
        ! xml_hash['Error']
      end
      
      def response_hash_message(xml_hash)
        response_hash_success?(xml_hash) ? '' : "FedEx Error Code: #{xml_hash['Error']['Code']}: #{xml_hash['Error']['Message']}"
      end
      
      def state_or_province(location)
        case
        when location.country == 'US' || location.country == 'USA' then
          location.state || location.province
        else
          location.province || location.state
        end
      end
      
      def zip_or_postal_code(location)
        case
        when location.country == 'US' || location.country == 'USA' then
          location.zip || location.postal_code
        else
          location.postal_code || location.zip
        end
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
