# -*- encoding: utf-8 -*-
require 'cgi'

module ActiveMerchant
  module Shipping

    # After getting an API login from USPS (looks like '123YOURNAME456'),
    # run the following test:
    #
    # usps = USPS.new(:login => '123YOURNAME456', :test => true)
    # usps.valid_credentials?
    #
    # This will send a test request to the USPS test servers, which they ask you
    # to do before they put your API key in production mode.
    class USPS < Carrier
      EventDetails = Struct.new(:description, :time, :zoneless_time, :location)
      EVENT_MESSAGE_PATTERNS = [
        /^(.*), (\w+ \d{1,2}, \d{4}, \d{1,2}:\d\d [ap]m), (.*), (\w\w) (\d{5})$/i,
        /^Your item \w{2,3} (out for delivery|delivered) at (\d{1,2}:\d\d [ap]m on \w+ \d{1,2}, \d{4}) in (.*), (\w\w) (\d{5})\.$/i
      ]
      self.retry_safe = true

      cattr_reader :name
      @@name = "USPS"

      LIVE_DOMAIN = 'production.shippingapis.com'
      LIVE_RESOURCE = 'ShippingAPI.dll'

      TEST_DOMAINS = { #indexed by security; e.g. TEST_DOMAINS[USE_SSL[:rates]]
        true => 'secure.shippingapis.com',
        false => 'testing.shippingapis.com'
      }

      TEST_RESOURCE = 'ShippingAPITest.dll'

      API_CODES = {
        :us_rates => 'RateV4',
        :world_rates => 'IntlRateV2',
        :test => 'CarrierPickupAvailability',
        :track => 'TrackV2'
      }
      USE_SSL = {
        :us_rates => false,
        :world_rates => false,
        :test => true,
        :track => false
      }
      CONTAINERS = {
        :envelope => 'Flat Rate Envelope',
        :box => 'Flat Rate Box'
      }
      MAIL_TYPES = {
        :package => 'Package',
        :postcard => 'Postcards or aerogrammes',
        :matter_for_the_blind => 'Matter for the blind',
        :envelope => 'Envelope'
      }

      PACKAGE_PROPERTIES = {
        'ZipOrigination' => :origin_zip,
        'ZipDestination' => :destination_zip,
        'Pounds' => :pounds,
        'Ounces' => :ounces,
        'Container' => :container,
        'Size' => :size,
        'Machinable' => :machinable,
        'Zone' => :zone,
        'Postage' => :postage,
        'Restrictions' => :restrictions
      }
      POSTAGE_PROPERTIES = {
        'MailService' => :service,
        'Rate' => :rate
      }
      US_SERVICES = {
        :first_class => 'FIRST CLASS',
        :priority => 'PRIORITY',
        :express => 'EXPRESS',
        :bpm => 'BPM',
        :parcel => 'PARCEL',
        :media => 'MEDIA',
        :library => 'LIBRARY',
        :online => 'ONLINE',
        :plus => 'PLUS',
        :all => 'ALL'
      }
      DEFAULT_SERVICE = Hash.new(:all).update(
        :base => :online,
        :plus => :plus
      )
      DOMESTIC_RATE_FIELD = Hash.new('Rate').update(
        :base => 'CommercialRate',
        :plus => 'CommercialPlusRate'
      )
      INTERNATIONAL_RATE_FIELD = Hash.new('Postage').update(
        :base => 'CommercialPostage',
        :plus => 'CommercialPlusPostage'
      )
      COMMERCIAL_FLAG_NAME = {
        :base => 'CommercialFlag',
        :plus => 'CommercialPlusFlag'
      }
      FIRST_CLASS_MAIL_TYPES = {
        :letter => 'LETTER',
        :flat => 'FLAT',
        :parcel => 'PARCEL',
        :post_card => 'POSTCARD',
        :package_service => 'PACKAGESERVICE'
      }

      # Array of U.S. possessions according to USPS: https://www.usps.com/ship/official-abbreviations.htm
      US_POSSESSIONS = ["AS", "FM", "GU", "MH", "MP", "PW", "PR", "VI"]

      # TODO: figure out how USPS likes to say "Ivory Coast"
      #
      # Country names:
      # http://pe.usps.gov/text/Imm/immctry.htm
      COUNTRY_NAME_CONVERSIONS = {
        "BA" => "Bosnia-Herzegovina",
        "CD" => "Congo, Democratic Republic of the",
        "CG" => "Congo (Brazzaville),Republic of the",
        "CI" => "Côte d'Ivoire (Ivory Coast)",
        "CK" => "Cook Islands (New Zealand)",
        "FK" => "Falkland Islands",
        "GB" => "Great Britain and Northern Ireland",
        "GE" => "Georgia, Republic of",
        "IR" => "Iran",
        "KN" => "Saint Kitts (St. Christopher and Nevis)",
        "KP" => "North Korea (Korea, Democratic People's Republic of)",
        "KR" => "South Korea (Korea, Republic of)",
        "LA" => "Laos",
        "LY" => "Libya",
        "MC" => "Monaco (France)",
        "MD" => "Moldova",
        "MK" => "Macedonia, Republic of",
        "MM" => "Burma",
        "PN" => "Pitcairn Island",
        "RU" => "Russia",
        "SK" => "Slovak Republic",
        "TK" => "Tokelau (Union) Group (Western Samoa)",
        "TW" => "Taiwan",
        "TZ" => "Tanzania",
        "VA" => "Vatican City",
        "VG" => "British Virgin Islands",
        "VN" => "Vietnam",
        "WF" => "Wallis and Futuna Islands",
        "WS" => "Western Samoa"
      }

      STATUS_NODE_PATTERNS = %w(
        Error/Description
        */TrackInfo/Error/Description
      )

      RESPONSE_ERROR_MESSAGES = [
        /There is no record of that mail item/,
        /This Information has not been included in this Test Server\./,
        /Delivery status information is not available/
      ]

      ESCAPING_AND_SYMBOLS = /&amp;lt;\S*&amp;gt;/
      LEADING_USPS = /^USPS/
      TRAILING_ASTERISKS = /\*+$/
      SERVICE_NAME_SUBSTITUTIONS = /#{ESCAPING_AND_SYMBOLS}|#{LEADING_USPS}|#{TRAILING_ASTERISKS}/

      def find_tracking_info(tracking_number, options={})
        options = @options.update(options)
        tracking_request = build_tracking_request(tracking_number, options)
        response = commit(:track, tracking_request, (options[:test] || false))
        parse_tracking_response(response, options)
      end

      def self.size_code_for(package)
        if package.inches(:max) <= 12
          'REGULAR'
        else
          'LARGE'
        end
      end

      # from info at http://www.usps.com/businessmail101/mailcharacteristics/parcels.htm
      #
      # package.options[:books] -- 25 lb. limit instead of 35 for books or other printed matter.
      #                             Defaults to false.
      def self.package_machinable?(package, options={})
        at_least_minimum =  package.inches(:length) >= 6.0 &&
                            package.inches(:width) >= 3.0 &&
                            package.inches(:height) >= 0.25 &&
                            package.ounces >= 6.0
        at_most_maximum  =  package.inches(:length) <= 34.0 &&
                            package.inches(:width) <= 17.0 &&
                            package.inches(:height) <= 17.0 &&
                            package.pounds <= (package.options[:books] ? 25.0 : 35.0)
        at_least_minimum && at_most_maximum
      end

      def requirements
        [:login]
      end

      def find_rates(origin, destination, packages, options = {})
        options = @options.merge(options)

        origin = Location.from(origin)
        destination = Location.from(destination)
        packages = Array(packages)

        #raise ArgumentError.new("USPS packages must originate in the U.S.") unless ['US',nil].include?(origin.country_code(:alpha2))

        # domestic or international?

        domestic_codes = US_POSSESSIONS + ['US', nil]
        response = if domestic_codes.include?(destination.country_code(:alpha2))
          us_rates(origin, destination, packages, options)
        else
          world_rates(origin, destination, packages, options)
        end
      end

      def valid_credentials?
        # Cannot test with find_rates because USPS doesn't allow that in test mode
        test_mode? ? canned_address_verification_works? : super
      end

      def maximum_weight
        Mass.new(70, :pounds)
      end

      def extract_event_details(message)
        return EventDetails.new unless EVENT_MESSAGE_PATTERNS.any?{|pattern| message =~ pattern}
        description = $1.upcase
        timestamp = $2
        city = $3
        state = $4
        zip_code = $5

        time = Time.parse(timestamp)
        zoneless_time = Time.utc(time.year, time.month, time.mday, time.hour, time.min, time.sec)
        location = Location.new(city: city, state: state, postal_code: zip_code, country: 'USA')
        EventDetails.new($1.upcase, time, zoneless_time, location)
      end

      protected

      def build_tracking_request(tracking_number, options={})
        xml_request = XmlNode.new('TrackRequest', 'USERID' => @options[:login]) do |root_node|
          root_node << XmlNode.new('TrackID', :ID => tracking_number)
        end
        URI.encode(xml_request.to_s)
      end

      def us_rates(origin, destination, packages, options={})
        request = build_us_rate_request(packages, origin.zip, destination.zip, options)
         # never use test mode; rate requests just won't work on test servers
        parse_rate_response origin, destination, packages, commit(:us_rates,request,false), options
      end

      def world_rates(origin, destination, packages, options={})
        request = build_world_rate_request(packages, destination, options)
         # never use test mode; rate requests just won't work on test servers
        parse_rate_response origin, destination, packages, commit(:world_rates,request,false), options
      end

      # Once the address verification API is implemented, remove this and have valid_credentials? build the request using that instead.
      def canned_address_verification_works?
        return false unless @options[:login]
        request = "%3CCarrierPickupAvailabilityRequest%20USERID=%22#{URI.encode(@options[:login])}%22%3E%20%0A%3CFirmName%3EABC%20Corp.%3C/FirmName%3E%20%0A%3CSuiteOrApt%3ESuite%20777%3C/SuiteOrApt%3E%20%0A%3CAddress2%3E1390%20Market%20Street%3C/Address2%3E%20%0A%3CUrbanization%3E%3C/Urbanization%3E%20%0A%3CCity%3EHouston%3C/City%3E%20%0A%3CState%3ETX%3C/State%3E%20%0A%3CZIP5%3E77058%3C/ZIP5%3E%20%0A%3CZIP4%3E1234%3C/ZIP4%3E%20%0A%3C/CarrierPickupAvailabilityRequest%3E%0A"
        # expected_hash = {"CarrierPickupAvailabilityResponse"=>{"City"=>"HOUSTON", "Address2"=>"1390 Market Street", "FirmName"=>"ABC Corp.", "State"=>"TX", "Date"=>"3/1/2004", "DayOfWeek"=>"Monday", "Urbanization"=>nil, "ZIP4"=>"1234", "ZIP5"=>"77058", "CarrierRoute"=>"C", "SuiteOrApt"=>"Suite 777"}}
        xml = REXML::Document.new(commit(:test, request, true))
        xml.get_text('/CarrierPickupAvailabilityResponse/City').to_s == 'HOUSTON' &&
        xml.get_text('/CarrierPickupAvailabilityResponse/Address2').to_s == '1390 Market Street'
      end

      # options[:service] --    One of [:first_class, :priority, :express, :bpm, :parcel,
      #                          :media, :library, :online, :plus, :all]. defaults to :all.
      # options[:container] --  One of [:envelope, :box]. defaults to neither (this field has
      #                          special meaning in the USPS API).
      # options[:books] --      Either true or false. Packages of books or other printed matter
      #                          have a lower weight limit to be considered machinable.
      # package.options[:machinable] -- Either true or false. Overrides the detection of
      #                                  "machinability" entirely.
      def build_us_rate_request(packages, origin_zip, destination_zip, options={})
        packages = Array(packages)
        request = XmlNode.new('RateV4Request', :USERID => @options[:login]) do |rate_request|
          packages.each_with_index do |p,id|
            rate_request << XmlNode.new('Package', :ID => id.to_s) do |package|
              commercial_type = commercial_type(options)
              default_service = DEFAULT_SERVICE[commercial_type]
              service         = options.fetch(:service, default_service).to_sym

              if commercial_type && service != default_service
                raise ArgumentError, "Commercial #{commercial_type} rates are only provided with the #{default_service.inspect} service."
              end

              package << XmlNode.new('Service', US_SERVICES[service])
              package << XmlNode.new('FirstClassMailType', FIRST_CLASS_MAIL_TYPES[options[:first_class_mail_type].try(:to_sym)])
              package << XmlNode.new('ZipOrigination', strip_zip(origin_zip))
              package << XmlNode.new('ZipDestination', strip_zip(destination_zip))
              package << XmlNode.new('Pounds', 0)
              package << XmlNode.new('Ounces', "%0.1f" % [p.ounces,1].max)
              package << XmlNode.new('Container', CONTAINERS[p.options[:container]])
              package << XmlNode.new('Size', USPS.size_code_for(p))
              package << XmlNode.new('Width', "%0.2f" % p.inches(:width))
              package << XmlNode.new('Length', "%0.2f" % p.inches(:length))
              package << XmlNode.new('Height', "%0.2f" % p.inches(:height))
              package << XmlNode.new('Girth', "%0.2f" % p.inches(:girth))
              is_machinable = if p.options.has_key?(:machinable)
                p.options[:machinable] ? true : false
              else
                USPS.package_machinable?(p)
              end
              package << XmlNode.new('Machinable', is_machinable.to_s.upcase)
            end
          end
        end
        URI.encode(save_request(request.to_s))
      end

      # important difference with international rate requests:
      # * services are not given in the request
      # * package sizes are not given in the request
      # * services are returned in the response along with restrictions of size
      # * the size restrictions are returned AS AN ENGLISH SENTENCE (!?)
      #
      #
      # package.options[:mail_type] -- one of [:package, :postcard, :matter_for_the_blind, :envelope].
      #                                 Defaults to :package.
      def build_world_rate_request(packages, destination, options)
        country = COUNTRY_NAME_CONVERSIONS[destination.country.code(:alpha2).value] || destination.country.name
        request = XmlNode.new('IntlRateV2Request', :USERID => @options[:login]) do |rate_request|
          packages.each_index do |id|
            p = packages[id]
            rate_request << XmlNode.new('Package', :ID => id.to_s) do |package|
              package << XmlNode.new('Pounds', 0)
              package << XmlNode.new('Ounces', [p.ounces,1].max.ceil) #takes an integer for some reason, must be rounded UP
              package << XmlNode.new('MailType', MAIL_TYPES[p.options[:mail_type]] || 'Package')
              package << XmlNode.new('GXG') do |gxg|
                gxg << XmlNode.new('POBoxFlag', destination.po_box? ? 'Y' : 'N')
                gxg << XmlNode.new('GiftFlag', p.gift? ? 'Y' : 'N')
              end
              value = if p.value && p.value > 0 && p.currency && p.currency != 'USD'
                0.0
              else
                (p.value || 0) / 100.0
              end
              package << XmlNode.new('ValueOfContents', value)
              package << XmlNode.new('Country') do |node|
                node.cdata = country
              end
              package << XmlNode.new('Container', p.cylinder? ? 'NONRECTANGULAR' : 'RECTANGULAR')
              package << XmlNode.new('Size', USPS.size_code_for(p))
              package << XmlNode.new('Width', "%0.2f" % [p.inches(:width), 0.01].max)
              package << XmlNode.new('Length', "%0.2f" % [p.inches(:length), 0.01].max)
              package << XmlNode.new('Height', "%0.2f" % [p.inches(:height), 0.01].max)
              package << XmlNode.new('Girth', "%0.2f" % [p.inches(:girth), 0.01].max)
              if commercial_type = commercial_type(options)
                package << XmlNode.new(COMMERCIAL_FLAG_NAME.fetch(commercial_type), 'Y')
              end
            end
          end
        end
        URI.encode(save_request(request.to_s))
      end

      def parse_rate_response(origin, destination, packages, response, options={})
        success = true
        message = ''
        rate_hash = {}

        xml = REXML::Document.new(response)

        if error = xml.elements['/Error']
          success = false
          message = error.elements['Description'].text
        else
          xml.elements.each('/*/Package') do |package|
            if package.elements['Error']
              success = false
              message = package.get_text('Error/Description').to_s
              break
            end
          end

          if success
            rate_hash = rates_from_response_node(xml, packages, options)
            unless rate_hash
              success = false
              message = "Unknown root node in XML response: '#{xml.root.name}'"
            end
          end

        end

        if success
          rate_estimates = rate_hash.keys.map do |service_name|
            RateEstimate.new(origin,destination,@@name,"USPS #{service_name}",
                                      :package_rates => rate_hash[service_name][:package_rates],
                                      :service_code => rate_hash[service_name][:service_code],
                                      :currency => 'USD')
          end
          rate_estimates.reject! {|e| e.package_count != packages.length}
          rate_estimates = rate_estimates.sort_by(&:total_price)
        end

        RateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :request => last_request)
      end

      def rates_from_response_node(response_node, packages, options = {})
        rate_hash = {}
        return false unless (root_node = response_node.elements['/IntlRateV2Response | /RateV4Response'])

        commercial_type = commercial_type(options)
        service_node, service_code_node, service_name_node, rate_node = if root_node.name == 'RateV4Response'
          %w[Postage CLASSID MailService] << DOMESTIC_RATE_FIELD[commercial_type]
        else
          %w[Service ID SvcDescription]   << INTERNATIONAL_RATE_FIELD[commercial_type]
        end

        root_node.each_element('Package') do |package_node|
          this_package = packages[package_node.attributes['ID'].to_i]

          package_node.each_element(service_node) do |service_response_node|
            service_name = service_response_node.get_text(service_name_node).to_s

            service_name.gsub!(SERVICE_NAME_SUBSTITUTIONS,'')
            service_name.strip!

            # aggregate specific package rates into a service-centric RateEstimate
            # first package with a given service name will initialize these;
            # later packages with same service will add to them
            this_service = rate_hash[service_name] ||= {}
            this_service[:service_code] ||= service_response_node.attributes[service_code_node]
            package_rates = this_service[:package_rates] ||= []
            this_package_rate = {:package => this_package,
                                 :rate => Package.cents_from(service_response_node.get_text(rate_node).to_s.to_f)}

            package_rates << this_package_rate if package_valid_for_service(this_package,service_response_node)
          end
        end
        rate_hash
      end

      def package_valid_for_service(package, service_node)
        return true if service_node.elements['MaxWeight'].nil?
        max_weight = service_node.get_text('MaxWeight').to_s.to_f
        name = service_node.get_text('SvcDescription | MailService').to_s.downcase

        if name =~ /flat.rate.box/ #domestic or international flat rate box
          # flat rate dimensions from http://www.usps.com/shipping/flatrate.htm
          return (package_valid_for_max_dimensions(package,
                      :weight => max_weight, #domestic apparently has no weight restriction
                      :length => 11.0,
                      :width => 8.5,
                      :height => 5.5) or
                 package_valid_for_max_dimensions(package,
                      :weight => max_weight,
                      :length => 13.625,
                      :width => 11.875,
                      :height => 3.375))
        elsif name =~ /flat.rate.envelope/
          return package_valid_for_max_dimensions(package,
                      :weight => max_weight,
                      :length => 12.5,
                      :width => 9.5,
                      :height => 0.75)
        elsif service_node.elements['MailService'] # domestic non-flat rates
          return true
        else #international non-flat rates
          # Some sample english that this is required to parse:
          #
          # 'Max. length 46", width 35", height 46" and max. length plus girth 108"'
          # 'Max. length 24", Max. length, height, depth combined 36"'
          #
          sentence = CGI.unescapeHTML(service_node.get_text('MaxDimensions').to_s)
          tokens = sentence.downcase.split(/[^\d]*"/).reject {|t| t.empty?}
          max_dimensions = {:weight => max_weight}
          single_axis_values = []
          tokens.each do |token|
            axis_sum = [/length/,/width/,/height/,/depth/].sum {|regex| (token =~ regex) ? 1 : 0}
            unless axis_sum == 0
              value = token[/\d+$/].to_f
              if axis_sum == 3
                max_dimensions[:length_plus_width_plus_height] = value
              elsif token =~ /girth/ and axis_sum == 1
                max_dimensions[:length_plus_girth] = value
              else
                single_axis_values << value
              end
            end
          end
          single_axis_values.sort!.reverse!
          [:length, :width, :height].each_with_index do |axis,i|
            max_dimensions[axis] = single_axis_values[i] if single_axis_values[i]
          end
          return package_valid_for_max_dimensions(package, max_dimensions)
        end
      end

      def package_valid_for_max_dimensions(package,dimensions)
        valid = ((not ([:length,:width,:height].map {|dim| dimensions[dim].nil? || dimensions[dim].to_f >= package.inches(dim).to_f}.include?(false))) and
                (dimensions[:weight].nil? || dimensions[:weight] >= package.pounds) and
                (dimensions[:length_plus_girth].nil? or
                    dimensions[:length_plus_girth].to_f >=
                    package.inches(:length) + package.inches(:girth)) and
                (dimensions[:length_plus_width_plus_height].nil? or
                    dimensions[:length_plus_width_plus_height].to_f >=
                    package.inches(:length) + package.inches(:width) + package.inches(:height)))

        return valid
      end

      def parse_tracking_response(response, options)
        actual_delivery_date, status = nil
        xml = REXML::Document.new(response)
        root_node = xml.elements['TrackResponse']

        success = response_success?(xml)
        message = response_message(xml)

        if success
          tracking_number, origin, destination = nil
          shipment_events = []
          tracking_details = xml.elements.collect('*/*/TrackDetail'){ |e| e }

          tracking_summary = xml.elements.collect('*/*/TrackSummary'){ |e| e }.first
          tracking_details << tracking_summary

          tracking_number = root_node.elements['TrackInfo'].attributes['ID'].to_s

          tracking_details.each do |event|
            details = extract_event_details(event.get_text.to_s)
            shipment_events << ShipmentEvent.new(details.description, details.zoneless_time, details.location) if details.location
          end

          shipment_events = shipment_events.sort_by(&:time)

          if last_shipment = shipment_events.last
            status = last_shipment.status
            actual_delivery_date = last_shipment.time if last_shipment.delivered?
          end
        end

        TrackingResponse.new(success, message, Hash.from_xml(response),
          :carrier => @@name,
          :xml => response,
          :request => last_request,
          :shipment_events => shipment_events,
          :destination => destination,
          :tracking_number => tracking_number,
          :status => status,
          :actual_delivery_date => actual_delivery_date
        )
      end

      def track_summary_node(document)
        document.elements['*/*/TrackSummary']
      end

      def error_description_node(document)
        STATUS_NODE_PATTERNS.each do |pattern|
          if node = document.elements[pattern]
            return node
          end
        end
      end

      def response_status_node(document)
         track_summary_node(document) || error_description_node(document)
      end

      def has_error?(document)
        !!document.elements['Error']
      end

      def no_record?(document)
        summary_node = track_summary_node(document)
        if summary_node
          summary = summary_node.get_text.to_s
          RESPONSE_ERROR_MESSAGES.detect { |re| summary =~ re }
          summary =~ /There is no record of that mail item/ || summary =~ /This Information has not been included in this Test Server\./
        else
          false
        end
      end

      def tracking_info_error?(document)
        document.elements['*/TrackInfo/Error']
      end

      def response_success?(document)
        !(has_error?(document) || no_record?(document) || tracking_info_error?(document))
      end

      def response_message(document)
        response_node = response_status_node(document)
        response_node.get_text.to_s
      end

      def commit(action, request, test = false)
        ssl_get(request_url(action, request, test))
      end

      def request_url(action, request, test)
        scheme = USE_SSL[action] ? 'https://' : 'http://'
        host = test ? TEST_DOMAINS[USE_SSL[action]] : LIVE_DOMAIN
        resource = test ? TEST_RESOURCE : LIVE_RESOURCE
        "#{scheme}#{host}/#{resource}?API=#{API_CODES[action]}&XML=#{request}"
      end

      def strip_zip(zip)
        zip.to_s.scan(/\d{5}/).first || zip
      end

      private

      def commercial_type(options)
        if options[:commercial_plus] == true
          :plus
        elsif options[:commercial_base] == true
          :base
        end
      end

    end
  end
end
