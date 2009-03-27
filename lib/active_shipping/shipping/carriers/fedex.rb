# FedEx module by Jimmy Baker
# http://github.com/jimmyebaker

module ActiveMerchant
  module Shipping
    
    # :login is your FedEx account number
    # :password is your meter number
    class FedEx < Carrier
      self.retry_safe = true
      
      cattr_reader :name
      @@name = "FedEx"
      
      TEST_URL = 'https://gatewaybeta.fedex.com/GatewayDC'
      LIVE_URL = 'https://gateway.fedex.com/GatewayDC'
      
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
      
      PackageIdentifierTypes = {
        'tracking_number' => 'TRACKING_NUMBER_OR_DOORTAG',
        'door_tag' => 'TRACKING_NUMBER_OR_DOORTAG',
        'rma' => 'RMA',
        'ground_shipment_id' => 'GROUND_SHIPMENT_ID',
        'ground_invoice_number' => 'GROUND_INVOICE_NUMBER',
        'ground_customer_reference' => 'GROUND_CUSTOMER_REFERENCE',
        'ground_po' => 'GROUND_PO',
        'express_reference' => 'EXPRESS_REFERENCE',
        'express_mps_master' => 'EXPRESS_MPS_MASTER'
      }
      
      def requirements
        [:login, :password]
      end
      
      def find_rates(origin, destination, packages, options = {})
        options = @options.update(options)
        packages = Array(packages)
        
        rate_request = build_rate_request(origin, destination, packages, nil, options)
        
        response = commit(save_request(rate_request), (options[:test] || false))
        
        parse_rate_response(origin, destination, packages, response, options)
      end
      
      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        
        tracking_request = build_tracking_request(tracking_number, options)
        response = commit(save_request(tracking_request), (options[:test] || false))
        parse_tracking_response(response, options)
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
          root_node << XmlNode.new('PackageCount', packages.length.to_s)
        end
        xml_request.to_xml
      end
      
      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('FDXTrackRequest', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXTrackRequest.xsd')
        xml_request << build_request_header(CarrierCodes[options[:carrier_code]] || CarrierCodes['fedex_ground'])
        xml_request << XmlNode.new('PackageIdentifier') do |pkg_xml|
          pkg_xml << XmlNode.new('Value', tracking_number)
          pkg_xml << XmlNode.new('Type', PackageIdentifierTypes[options['package_identifier_type'] || 'tracking_number'])
        end
        xml_request << XmlNode.new('ShipDateRangeBegin', options['ship_date_range_begin']) if options['ship_date_range_begin']
        xml_request << XmlNode.new('ShipDateRangeEnd', options['ship_date_range_end']) if options['ship_date_range_end']
        xml_request << XmlNode.new('ShipDate', options['ship_date']) if options['ship_date']
        xml_request << XmlNode.new('DetailScans', options['detail_scans'] || 'true')
        xml_request.to_xml
        # DestinationCountryCode not implemented
      end
      
      def build_request_header(carrier_code='FDXG')
        xml_request = XmlNode.new('RequestHeader') do |access_request|
          access_request << XmlNode.new('AccountNumber', @options[:login])
          access_request << XmlNode.new('MeterNumber', @options[:password])
          if carrier_code
            access_request << XmlNode.new('CarrierCode', carrier_code)
          end
        end
        xml_request
      end
      
      def build_location_node(name, location)
        location_node = XmlNode.new(name) do |xml_node|
          xml_node << XmlNode.new('StateOrProvinceCode', location.state)
          xml_node << XmlNode.new('PostalCode', location.postal_code)
          xml_node << XmlNode.new("CountryCode", location.country_code(:alpha2))
        end
      end
      
      def parse_rate_response(origin, destination, packages, response, options)
        rates = []
        rate_estimates = []
        success, message = nil
        
        xml = REXML::Document.new(response)
        root_node = xml.elements['FDXRateAvailableServicesReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        root_node.elements.each('Entry') do |rated_shipment|
          service_code = rated_shipment.get_text('Service').to_s
          rate_estimates << RateEstimate.new(origin, destination, @@name,
                              ServiceTypes[service_code],
                              :service_code => service_code,
                              :total_price => rated_shipment.get_text('EstimatedCharges/DiscountedCharges/NetCharge').to_s.to_f,
                              :currency => rated_shipment.get_text('EstimatedCharges/CurrencyCode').to_s,
                              :packages => packages)
        end
        
        if rate_estimates.empty?
          success = false
          message = "No shipping rates could be found for the destination address" if message.blank?
        end        

        RateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :request => last_request, :log_xml => options[:log_xml])
      end
      
      def parse_tracking_response(response, options)
        xml_hash = Hash.from_xml(response)['FDXTrackReply']
        xml = REXML::Document.new(response)
        root_node = xml.elements['FDXTrackReply']
        
        success = response_success?(xml)
        message = response_message(xml)
        
        if success
          tracking_number, origin, destination = nil
          shipment_events = []
          
          first_shipment = root_node.elements['TrackProfile']
          tracking_number = first_shipment.get_text('TrackingNumber').to_s
          
          destination_node = first_shipment.elements['DestinationAddress']
          destination = Location.new(
                :country =>     destination_node.get_text('CountryCode').to_s,
                :postal_code => destination_node.get_text('PostalCode').to_s,
                :province =>    destination_node.get_text('StateOrProvinceCode').to_s,
                :city =>        destination_node.get_text('City').to_s
              )
          
          first_shipment.elements.each('Scan') do |activity|
            location = Location.new(
              :city => activity.get_text('City').to_s,
              :state => activity.get_text('StateOrProvinceCode').to_s,
              :postal_code => activity.get_text('PostalCode').to_s,
              :country => activity.get_text('CountryCode').to_s)
            description = activity.elements['ScanDescription']
            description = description ? description.get_text.to_s : ''
            
            # for now, just assume UTC, even though it probably isn't
            time = Time.parse("#{activity.get_text('Date').to_s} #{activity.get_text('Time').to_s}")
            zoneless_time = Time.utc(time.year, time.month, time.mday, time.hour, time.min, time.sec)
            
            if description.downcase == 'delivered'
              shipment_events << ShipmentEvent.new(description, zoneless_time, location, "Signed for by: #{first_shipment.get_text('SignedForBy').to_s}")
            else
              shipment_events << ShipmentEvent.new(description, zoneless_time, location)
            end
          end
          shipment_events = shipment_events.sort_by(&:time)
        end
        
        TrackingResponse.new(success, message, Hash.from_xml(response),
          :xml => response,
          :request => last_request,
          :shipment_events => shipment_events,
          :destination => destination,
          :tracking_number => tracking_number
        )
      end
      
      def response_error_node(document)
        document.elements['/*/Error|/*/SoftError)']
      end
      
      def response_success?(document)
        response_error_node(document) ? false : true
      end
      
      def response_message(document)
        error_node = response_error_node(document)
        if error_node
          "FedEx Error Code: #{error_node.get_text('Code').to_s}: #{error_node.get_text('Message').to_s}"
        else
          ''
        end
      end
      
      def commit(request, test = false)
        ssl_post(test ? TEST_URL : LIVE_URL, request.gsub("\n",''))        
      end
    end
  end
end
