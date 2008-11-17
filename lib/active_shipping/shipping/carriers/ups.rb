module ActiveMerchant
  module Shipping
    class UPS < Carrier
      cattr_accessor :default_options
      cattr_reader :name
      @@name = "UPS"
      
      TEST_DOMAIN = 'wwwcie.ups.com'
      LIVE_DOMAIN = 'www.ups.com'
      
      RESOURCES = {
        :rates => '/ups.app/xml/Rate',
        :track => '/ups.app/xml/Track'
      }
      
      USE_SSL = {
        :rates => true,
        :track => true
      }
      
      PICKUP_CODES = {
        :daily_pickup => "01",
        :customer_counter => "03", 
        :one_time_pickup => "06",
        :on_call_air => "07",
        :suggested_retail_rates => "11",
        :letter_center => "19",
        :air_service_center => "20"
      }
      
      DEFAULT_SERVICES = {
        "01" => "UPS Next Day Air",
        "02" => "UPS Second Day Air",
        "03" => "UPS Ground",
        "07" => "UPS Worldwide Express",
        "08" => "UPS Worldwide Expedited",
        "11" => "UPS Standard",
        "12" => "UPS Three-Day Select",
        "13" => "UPS Next Day Air Saver",
        "14" => "UPS Next Day Air Early A.M.",
        "54" => "UPS Worldwide Express Plus",
        "59" => "UPS Second Day Air A.M.",
        "65" => "UPS Saver",
        "82" => "UPS Today Standard",
        "83" => "UPS Today Dedicated Courier",
        "84" => "UPS Today Intercity",
        "85" => "UPS Today Express",
        "86" => "UPS Today Express Saver"
      }
      
      CANADA_ORIGIN_SERVICES = {
        "01" => "UPS Express",
        "02" => "UPS Expedited",
        "14" => "UPS Express Early A.M."
      }
      
      MEXICO_ORIGIN_SERVICES = {
        "07" => "UPS Express",
        "08" => "UPS Expedited",
        "54" => "UPS Express Plus"
      }
      
      EU_ORIGIN_SERVICES = {
        "07" => "UPS Express",
        "08" => "UPS Expedited"
      }
      
      OTHER_NON_US_ORIGIN_SERVICES = {
        "07" => "UPS Express"
      }
      
      # From http://en.wikipedia.org/w/index.php?title=European_Union&oldid=174718707 (Current as of November 30, 2007)
      EU_COUNTRY_CODES = ["GB", "AT", "BE", "BG", "CY", "CZ", "DK", "EE", "FI", "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU", "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE"]
      
      def requirements
        [:key, :login, :password]
      end
      
      def find_rates(origin, destination, packages, options={})
        options = @options.update(options)
        packages = Array(packages)
        access_request = build_access_request
        rate_request = build_rate_request(origin, destination, packages, options)
        response = commit(:rates, save_request(access_request + rate_request), (options[:test] || false))
        parse_rate_response(origin, destination, packages, response, options)
      end
      
      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        access_request = build_access_request
        tracking_request = build_tracking_request(tracking_number, options)
        response = commit(:track, save_request(access_request + tracking_request), (options[:test] || false))
        parse_tracking_response(response, options)
      end
      
      protected
      def build_access_request
        xml_request = XmlNode.new('AccessRequest') do |access_request|
          access_request << XmlNode.new('AccessLicenseNumber', @options[:key])
          access_request << XmlNode.new('UserId', @options[:login])
          access_request << XmlNode.new('Password', @options[:password])
        end
        xml_request.to_xml
      end
      
      def build_rate_request(origin, destination, packages, options={})
        packages = Array(packages)
        xml_request = XmlNode.new('RatingServiceSelectionRequest') do |root_node|
          root_node << XmlNode.new('Request') do |request|
            request << XmlNode.new('RequestAction', 'Rate')
            request << XmlNode.new('RequestOption', 'Shop')
            # not implemented: 'Rate' RequestOption to specify a single service query
            # request << XmlNode.new('RequestOption', ((options[:service].nil? or options[:service] == :all) ? 'Shop' : 'Rate'))
          end
          root_node << XmlNode.new('PickupType') do |pickup_type|
            pickup_type << XmlNode.new('Code', PICKUP_CODES[options[:pickup_type] || :daily_pickup])
            # not implemented: PickupType/PickupDetails element
          end
          # not implemented: CustomerClassification element
          root_node << XmlNode.new('Shipment') do |shipment|
            # not implemented: Shipment/Description element
            shipment << build_location_node('Shipper', (options[:shipper] || origin), options)
            shipment << build_location_node('ShipTo', destination, options)
            if options[:shipper] and options[:shipper] != origin
              shipment << build_location_node('ShipFrom', origin, options)
            end
            
            # not implemented:  * Shipment/ShipmentWeight element
            #                   * Shipment/ReferenceNumber element                    
            #                   * Shipment/Service element                            
            #                   * Shipment/PickupDate element                         
            #                   * Shipment/ScheduledDeliveryDate element              
            #                   * Shipment/ScheduledDeliveryTime element              
            #                   * Shipment/AlternateDeliveryTime element              
            #                   * Shipment/DocumentsOnly element                      
            
            packages.each do |package|
              
              
              imperial = ['US','LR','MM'].include?(origin.country_code(:alpha2))
              
              shipment << XmlNode.new("Package") do |package_node|
                
                # not implemented:  * Shipment/Package/PackagingType element
                #                   * Shipment/Package/Description element
                
                package_node << XmlNode.new("PackagingType") do |packaging_type|
                  packaging_type << XmlNode.new("Code", '02')
                end
                
                package_node << XmlNode.new("Dimensions") do |dimensions|
                  dimensions << XmlNode.new("UnitOfMeasurement") do |units|
                    units << XmlNode.new("Code", imperial ? 'IN' : 'CM')
                  end
                  [:length,:width,:height].each do |axis|
                    value = ((imperial ? package.inches(axis) : package.cm(axis)).to_f*1000).round/1000.0 # 3 decimals
                    dimensions << XmlNode.new(axis.to_s.capitalize, [value,0.1].max)
                  end
                end
              
                package_node << XmlNode.new("PackageWeight") do |package_weight|
                  package_weight << XmlNode.new("UnitOfMeasurement") do |units|
                    units << XmlNode.new("Code", imperial ? 'LBS' : 'KGS')
                  end
                  
                  value = ((imperial ? package.lbs : package.kgs).to_f*1000).round/1000.0 # 3 decimals
                  package_weight << XmlNode.new("Weight", [value,0.1].max)
                end
              
                # not implemented:  * Shipment/Package/LargePackageIndicator element
                #                   * Shipment/Package/ReferenceNumber element
                #                   * Shipment/Package/PackageServiceOptions element
                #                   * Shipment/Package/AdditionalHandling element  
              end
              
            end
            
            # not implemented:  * Shipment/ShipmentServiceOptions element
            #                   * Shipment/RateInformation element
            
          end
          
        end
        xml_request.to_xml
      end
      
      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('TrackRequest') do |root_node|
          root_node << XmlNode.new('Request') do |request|
            request << XmlNode.new('RequestAction', 'Track')
            request << XmlNode.new('RequestOption', '1')
          end
          root_node << XmlNode.new('TrackingNumber', tracking_number.to_s)
        end
        xml_request.to_xml
      end
      
      def build_location_node(name,location,options={})
        # not implemented:  * Shipment/Shipper/Name element
        #                   * Shipment/(ShipTo|ShipFrom)/CompanyName element
        #                   * Shipment/(Shipper|ShipTo|ShipFrom)/AttentionName element
        #                   * Shipment/(Shipper|ShipTo|ShipFrom)/TaxIdentificationNumber element
        location_node = XmlNode.new(name) do |location_node|
          location_node << XmlNode.new('PhoneNumber', location.phone.gsub(/[^\d]/,'')) unless location.phone.blank?
          location_node << XmlNode.new('FaxNumber', location.fax.gsub(/[^\d]/,'')) unless location.fax.blank?
          
          if name == 'Shipper' and (origin_account = @options[:origin_account] || options[:origin_account])
            location_node << XmlNode.new('ShipperNumber', origin_account)
          elsif name == 'ShipTo' and (destination_account = @options[:destination_account] || options[:destination_account])
            location_node << XmlNode.new('ShipperAssignedIdentificationNumber', destination_account)
          end
          
          location_node << XmlNode.new('Address') do |address|
            address << XmlNode.new("AddressLine1", location.address1) unless location.address1.blank?
            address << XmlNode.new("AddressLine2", location.address2) unless location.address2.blank?
            address << XmlNode.new("AddressLine3", location.address3) unless location.address3.blank?
            address << XmlNode.new("City", location.city) unless location.city.blank?
            address << XmlNode.new("StateProvinceCode", location.province) unless location.province.blank?
              # StateProvinceCode required for negotiated rates but not otherwise, for some reason
            address << XmlNode.new("PostalCode", location.postal_code) unless location.postal_code.blank?
            address << XmlNode.new("CountryCode", location.country_code(:alpha2)) unless location.country_code(:alpha2).blank?
            address << XmlNode.new("ResidentialAddressIndicator", true) unless location.commercial? # the default should be that UPS returns residential rates for destinations that it doesn't know about
            # not implemented: Shipment/(Shipper|ShipTo|ShipFrom)/Address/ResidentialAddressIndicator element
          end
        end
      end
      
      def parse_rate_response(origin, destination, packages, response, options={})
        rates = []
        
        xml_hash = Hash.from_xml(response)['RatingServiceSelectionResponse']
        success = response_hash_success?(xml_hash)
        message = response_hash_message(xml_hash)
        
        if success
          rate_estimates = []
          
          xml_hash['RatedShipment'] = [xml_hash['RatedShipment']] unless xml_hash['RatedShipment'].is_a? Array
          xml_hash['RatedShipment'].each do |rated_shipment|
            service_code = rated_shipment['Service']['Code']
            rate_estimates << RateEstimate.new(origin, destination, @@name,
                                service_name_for(origin, service_code),
                                :total_price => rated_shipment['TotalCharges']['MonetaryValue'].to_f,
                                :currency => rated_shipment['TotalCharges']['CurrencyCode'],
                                :service_code => service_code,
                                :packages => packages)
          end
        end
        RateResponse.new(success, message, xml_hash, :rates => rate_estimates, :xml => response, :request => last_request)
      end
      
      def parse_tracking_response(response, options={})
        xml_hash = Hash.from_xml(response)['TrackResponse']
        success = response_hash_success?(xml_hash)
        message = response_hash_message(xml_hash)
        
        
        if success
          tracking_number, origin, destination = nil
          shipment_events = []
          
          first_shipment = first_or_only(xml_hash['Shipment'])
          first_package = first_or_only(first_shipment['Package'])
          tracking_number = first_shipment['ShipmentIdentificationNumber'] || first_package['TrackingNumber']
          origin, destination = %w{Shipper ShipTo}.map do |location|
            location_hash = first_shipment[location]
            if location_hash && (address_hash = location_hash['Address'])
              Location.new(
                :country =>     address_hash['CountryCode'],
                :postal_code => address_hash['PostalCode'],
                :province =>    address_hash['StateProvinceCode'],
                :city =>        address_hash['City'],
                :address1 =>    address_hash['AddressLine1'],
                :address2 =>    address_hash['AddressLine2'],
                :address3 =>    address_hash['AddressLine3']
              )
            else
              nil
            end
          end
          
          activities = force_array(first_package['Activity'])
          unless activities.empty?
            shipment_events = activities.map do |activity|
              address = activity['ActivityLocation']['Address']
              location = Location.new(
                :address1 => address['AddressLine1'],
                :address2 => address['AddressLine2'],
                :address3 => address['AddressLine3'],
                :city => address['City'],
                :state => address['StateProvinceCode'],
                :postal_code => address['PostalCode'],
                :country => address['CountryCode'])
              status = activity['Status']
              status_type = status['StatusType'] if status
              description = status_type['Description'] if status_type
            
              # for now, just assume UTC, even though it probably isn't
              zoneless_time = if activity['Time'] and activity['Date']
                hour, minute, second = activity['Time'].scan(/\d{2}/)
                year, month, day = activity['Date'][0..3], activity['Date'][4..5], activity['Date'][6..7]
                Time.utc(year , month, day, hour, minute, second)
              end
              ShipmentEvent.new(description, zoneless_time, location)
            end
            
            shipment_events = shipment_events.sort_by(&:time)
            
            if origin
              first_event = shipment_events[0]
              same_country = origin.country_code(:alpha2) == first_event.location.country_code(:alpha2)
              same_or_blank_city = first_event.location.city.blank? or first_event.location.city == origin.city
              origin_event = ShipmentEvent.new(first_event.name, first_event.time, origin)
              if same_country and same_or_blank_city
                shipment_events[0] = origin_event
              else
                shipment_events.unshift(origin_event)
              end
            end
            if shipment_events.last.name.downcase == 'delivered'
              shipment_events[-1] = ShipmentEvent.new(shipment_events.last.name, shipment_events.last.time, destination)
            end
          end
        end
        
        TrackingResponse.new(success, message, xml_hash,
          :xml => response,
          :request => last_request,
          :shipment_events => shipment_events,
          :origin => origin,
          :destination => destination,
          :tracking_number => tracking_number)
      end
      
      def first_or_only(xml_hash)
        xml_hash.is_a?(Array) ? xml_hash.first : xml_hash
      end
      
      def force_array(obj)
        obj.is_a?(Array) ? obj : [obj]
      end
      
      def response_hash_success?(xml_hash)
        xml_hash['Response']['ResponseStatusCode'] == '1'
      end
      
      def response_hash_message(xml_hash)
        response_hash_success?(xml_hash) ?
          xml_hash['Response']['ResponseStatusDescription'] :
          xml_hash['Response']['Error']['ErrorDescription']
      end
      
      def commit(action, request, test = false)
        http = Net::HTTP.new((test ? TEST_DOMAIN : LIVE_DOMAIN),
                              (USE_SSL[action] ? 443 : 80 ))
        http.use_ssl = USE_SSL[action]
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if USE_SSL[action]
        response = http.start do |http|
          http.post RESOURCES[action], request
        end
        response.body
      end
      
      
      def service_name_for(origin, code)
        origin = origin.country_code(:alpha2)
        
        name = case origin
        when "CA": CANADA_ORIGIN_SERVICES[code]
        when "MX": MEXICO_ORIGIN_SERVICES[code]
        when *EU_COUNTRY_CODES: EU_ORIGIN_SERVICES[code]
        end
        
        name ||= OTHER_NON_US_ORIGIN_SERVICES[code] unless name == 'US'
        name ||= DEFAULT_SERVICES[code]
      end
      
    end
  end
end