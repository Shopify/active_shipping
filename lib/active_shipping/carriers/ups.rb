# -*- encoding: utf-8 -*-

module ActiveShipping
  class UPS < Carrier
    self.retry_safe = true

    cattr_accessor :default_options
    cattr_reader :name
    @@name = "UPS"

    TEST_URL = 'https://wwwcie.ups.com'
    LIVE_URL = 'https://onlinetools.ups.com'

    RESOURCES = {
      :rates => 'ups.app/xml/Rate',
      :track => 'ups.app/xml/Track',
      :ship_confirm => 'ups.app/xml/ShipConfirm',
      :ship_accept => 'ups.app/xml/ShipAccept'
    }

    PICKUP_CODES = HashWithIndifferentAccess.new(
      :daily_pickup => "01",
      :customer_counter => "03",
      :one_time_pickup => "06",
      :on_call_air => "07",
      :suggested_retail_rates => "11",
      :letter_center => "19",
      :air_service_center => "20"
    )

    CUSTOMER_CLASSIFICATIONS = HashWithIndifferentAccess.new(
      :wholesale => "01",
      :occasional => "03",
      :retail => "04"
    )

    # these are the defaults described in the UPS API docs,
    # but they don't seem to apply them under all circumstances,
    # so we need to take matters into our own hands
    DEFAULT_CUSTOMER_CLASSIFICATIONS = Hash.new do |hash, key|
      hash[key] = case key.to_sym
      when :daily_pickup then :wholesale
      when :customer_counter then :retail
      else
        :occasional
      end
    end

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

    TRACKING_STATUS_CODES = HashWithIndifferentAccess.new(
      'I' => :in_transit,
      'D' => :delivered,
      'X' => :exception,
      'P' => :pickup,
      'M' => :manifest_pickup
    )

    # From http://en.wikipedia.org/w/index.php?title=European_Union&oldid=174718707 (Current as of November 30, 2007)
    EU_COUNTRY_CODES = %w(GB AT BE BG CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE)

    US_TERRITORIES_TREATED_AS_COUNTRIES = %w(AS FM GU MH MP PW PR VI)

    IMPERIAL_COUNTRIES = %w(US LR MM)

    def requirements
      [:key, :login, :password]
    end

    def find_rates(origin, destination, packages, options = {})
      origin, destination = upsified_location(origin), upsified_location(destination)
      options = @options.merge(options)
      packages = Array(packages)
      access_request = build_access_request
      rate_request = build_rate_request(origin, destination, packages, options)
      response = commit(:rates, save_request(access_request + rate_request), options[:test])
      parse_rate_response(origin, destination, packages, response, options)
    end

    def find_tracking_info(tracking_number, options = {})
      options = @options.update(options)
      access_request = build_access_request
      tracking_request = build_tracking_request(tracking_number, options)
      response = commit(:track, save_request(access_request + tracking_request), options[:test])
      parse_tracking_response(response, options)
    end

    def create_shipment(origin, destination, packages, options = {})
      options = @options.merge(options)
      packages = Array(packages)
      access_request = build_access_request

      begin

        # STEP 1: Confirm.  Validation step, important for verifying price.
        confirm_request = build_shipment_request(origin, destination, packages, options)
        logger.debug(confirm_request) if logger

        confirm_response = commit(:ship_confirm, save_request(access_request + confirm_request), (options[:test] || false))
        logger.debug(confirm_response) if logger

        # ... now, get the digest, it's needed to get the label.  In theory,
        # one could make decisions based on the price or some such to avoid
        # surprises.  This also has *no* error handling yet.
        xml = parse_ship_confirm(confirm_response)
        success = response_success?(xml)
        message = response_message(xml)
        digest  = response_digest(xml)
        raise message unless success

        # STEP 2: Accept. Use shipment digest in first response to get the actual label.
        accept_request = build_accept_request(digest, options)
        logger.debug(accept_request) if logger

        accept_response = commit(:ship_accept, save_request(access_request + accept_request), (options[:test] || false))
        logger.debug(accept_response) if logger

        # ...finally, build a map from the response that contains
        # the label data and tracking information.
        parse_ship_accept(accept_response)

      rescue RuntimeError => e
        raise "Could not obtain shipping label. #{e.message}."

      end
    end

    protected

    def upsified_location(location)
      if location.country_code == 'US' && US_TERRITORIES_TREATED_AS_COUNTRIES.include?(location.state)
        atts = {:country => location.state}
        [:zip, :city, :address1, :address2, :address3, :phone, :fax, :address_type].each do |att|
          atts[att] = location.send(att)
        end
        Location.new(atts)
      else
        location
      end
    end

    def build_access_request
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.AccessRequest do
          xml.AccessLicenseNumber(@options[:key])
          xml.UserId(@options[:password])
          xml.Password(@options[:password])
        end
      end
      xml_builder.to_xml
    end

    def build_rate_request(origin, destination, packages, options = {})
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.RatingServiceSelectionRequest do
          xml.Request do
            xml.RequestAction('Rate')
            xml.RequestOption('Shop')
            # not implemented: 'Rate' RequestOption to specify a single service query
            # xml.RequestOption((options[:service].nil? or options[:service] == :all) ? 'Shop' : 'Rate')
          end

          pickup_type = options[:pickup_type] || :daily_pickup

          xml.PickupType do
            xml.Code(PICKUP_CODES[pickup_type])
            # not implemented: PickupType/PickupDetails element
          end

          cc = options[:customer_classification] || DEFAULT_CUSTOMER_CLASSIFICATIONS[pickup_type]
          xml.CustomerClassification do
            xml.Code(CUSTOMER_CLASSIFICATIONS[cc])
          end

          xml.Shipment do
            # not implemented: Shipment/Description element
            build_location_node(xml, 'Shipper', (options[:shipper] || origin), options)
            build_location_node(xml, 'ShipTo', destination, options)
            build_location_node(xml, 'ShipFrom', origin, options) if options[:shipper] && options[:shipper] != origin

            # not implemented:  * Shipment/ShipmentWeight element
            #                   * Shipment/ReferenceNumber element
            #                   * Shipment/Service element
            #                   * Shipment/PickupDate element
            #                   * Shipment/ScheduledDeliveryDate element
            #                   * Shipment/ScheduledDeliveryTime element
            #                   * Shipment/AlternateDeliveryTime element
            #                   * Shipment/DocumentsOnly element

            Array(packages).each do |package|
              options[:imperial] ||= IMPERIAL_COUNTRIES.include?(origin.country_code(:alpha2))
              build_package_node(xml, package, options)
            end

            # not implemented:  * Shipment/ShipmentServiceOptions element
            if options[:origin_account]
              xml.RateInformation do
                xml.NegotiatedRatesIndicator
              end
            end
          end
        end
      end
      xml_builder.to_xml
    end

    # Build XML node to request a shipping label for the given packages.
    #
    # options:
    # * origin_account: who will pay for the shipping label
    # * customer_context: a "guid like substance" -- according to UPS
    # * shipper: who is sending the package and where it should be returned
    #     if it is undeliverable.
    # * ship_from: where the package is picked up.
    # * service_code: default to '14'
    # * service_descriptor: default to 'Next Day Air Early AM'
    # * saturday_delivery: any truthy value causes this element to exist
    # * optional_processing: 'validate' (blank) or 'nonvalidate' or blank
    #
    def build_shipment_request(origin, destination, packages, options = {})
      # There are a lot of unimplemented elements, documenting all of them
      # wouldprobably be unhelpful.
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.ShipmentConfirmRequest do
          xml.Request do
            # Required element and the text must be "ShipConfirm"
            xml.RequestAction('ShipConfirm')
            # Required element cotnrols level of address validation.
            xml.RequestOption(options[:optional_processing] || 'validate')
            # Optional element to identify transactions between client and server.
            if options[:customer_context]
              xml.TransactionReference do
                xml.CustomerContext(options[:customer_context])
              end
            end
          end

          xml.Shipment do
            # Required element.
            xml.Service do
              xml.Code(options[:service_code] || '14')
              xml.Description(options[:service_description] || 'Next Day Air Early AM')
            end

            # Required element. The delivery destination.
            build_location_node(xml, 'ShipTo', destination, {})
            # Required element. The company whose account is responsible for the label(s).
            build_location_node(xml, 'Shipper', options[:shipper] || origin, {})
            # Required if pickup is different different from shipper's address.
            build_location_node(xml, 'ShipFrom', options[:ship_from], {}) if options[:ship_from]

            # Optional.
            if options[:saturday_delivery]
              xml.ShipmentServiceOptions do
                xml.SaturdayDelivery
              end
            end

            # Optional.
            if options[:origin_account]
              xml.RateInformation do
                xml.NegotiatedRatesIndicator
              end
            end

            # Optional.
            if options[:shipment] && options[:shipment][:reference_number]
              xml.ReferenceNumber do
                xml.Code(options[:shipment][:reference_number][:code] || "")
                xml.Value(options[:shipment][:reference_number][:value])
              end
            end

            # Conditionally required.  Either this element or an ItemizedPaymentInformation
            # is needed.  However, only PaymentInformation is not implemented.
            xml.PaymentInformation do
              xml.Prepaid do
                xml.BillShipper do
                  xml.AccountNumber(options[:origin_account])
                end
              end
            end

            # A request may specify multiple packages.
            options[:imperial] ||= IMPERIAL_COUNTRIES.include?(origin.country_code(:alpha2))
            Array(packages).each do |package|
              build_package_node(xml, package, options)
            end
          end

          # I don't know all of the options that UPS supports for labels
          # so I'm going with something very simple for now.
          xml.LabelSpecification do
            xml.LabelPrintMethod do
              xml.Code('GIF')
            end
            xml.HTTPUserAgent('Mozilla/4.5') # hmmm
            xml.LabelImageFormat('GIF') do
              xml.Code('GIF')
            end
          end
        end
      end
      xml_builder.to_xml
    end

    def build_accept_request(digest, options = {})
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.ShipmentAcceptRequest do
          xml.Request do
            xml.RequestAction('ShipAccept')
          end
          xml.ShipmentDigest(digest)
        end
      end
      xml_builder.to_xml
    end

    def build_tracking_request(tracking_number, options = {})
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.TrackRequest do
          xml.Request do
            xml.RequestAction('Track')
            xml.RequestOption('1')
          end
          xml.TrackingNumber(tracking_number.to_s)
        end
      end
      xml_builder.to_xml
    end

    def build_location_node(xml, name, location, options = {})
      # not implemented:  * Shipment/Shipper/Name element
      #                   * Shipment/(ShipTo|ShipFrom)/CompanyName element
      #                   * Shipment/(Shipper|ShipTo|ShipFrom)/AttentionName element
      #                   * Shipment/(Shipper|ShipTo|ShipFrom)/TaxIdentificationNumber element
      xml.public_send(name) do
        # You must specify the shipper name when creating labels.
        if shipper_name = (options[:origin_name] || @options[:origin_name])
          xml.Name(shipper_name)
        end
        xml.PhoneNumber(location.phone.gsub(/[^\d]/, '')) unless location.phone.blank?
        xml.FaxNumber(location.fax.gsub(/[^\d]/, '')) unless location.fax.blank?

        if name == 'Shipper' and (origin_account = options[:origin_account] || @options[:origin_account])
          xml.ShipperNumber(origin_account)
        elsif name == 'ShipTo' and (destination_account = options[:destination_account] || @options[:destination_account])
          xml.ShipperAssignedIdentificationNumber(destination_account)
        end

        if name = location.company_name || location.name
          xml.CompanyName(name)
        end

        if phone = location.phone
          xml.PhoneNumber(phone)
        end

        if attn = location.name
          xml.AttentionName(attn)
        end

        xml.Address do
          xml.AddressLine1(location.address1) unless location.address1.blank?
          xml.AddressLine2(location.address2) unless location.address2.blank?
          xml.AddressLine3(location.address3) unless location.address3.blank?
          xml.City(location.city) unless location.city.blank?
          xml.StateProvinceCode(location.province) unless location.province.blank?
          # StateProvinceCode required for negotiated rates but not otherwise, for some reason
          xml.PostalCode(location.postal_code) unless location.postal_code.blank?
          xml.CountryCode(location.country_code(:alpha2)) unless location.country_code(:alpha2).blank?
          xml.ResidentialAddressIndicator(true) unless location.commercial? # the default should be that UPS returns residential rates for destinations that it doesn't know about
          # not implemented: Shipment/(Shipper|ShipTo|ShipFrom)/Address/ResidentialAddressIndicator element
        end
      end
    end

    def build_package_node(xml, package, options = {})
      xml.Package do

        # not implemented:  * Shipment/Package/PackagingType element
        #                   * Shipment/Package/Description element

        xml.PackagingType do
          xml.Code('02')
        end

        xml.Dimensions do
          xml.UnitOfMeasurement do
            xml.Code(options[:imperial] ? 'IN' : 'CM')
          end
          [:length, :width, :height].each do |axis|
            value = ((options[:imperial] ? package.inches(axis) : package.cm(axis)).to_f * 1000).round / 1000.0 # 3 decimals
            xml.public_send(axis.to_s.capitalize, [value, 0.1].max)
          end
        end

        xml.PackageWeight do
          xml.UnitOfMeasurement do
            xml.Code(options[:imperial] ? 'LBS' : 'KGS')
          end

          value = ((options[:imperial] ? package.lbs : package.kgs).to_f * 1000).round / 1000.0 # 3 decimals
          xml.Weight([value, 0.1].max)
        end

        if options[:package] && options[:package][:reference_number]
          xml.ReferenceNumber do
            xml.Code(options[:package][:reference_number][:code] || "")
            xml.Value(options[:package][:reference_number][:value])
          end
        end

        # not implemented:  * Shipment/Package/LargePackageIndicator element
        #                   * Shipment/Package/PackageServiceOptions element
        #                   * Shipment/Package/AdditionalHandling element
      end
    end

    def build_document(xml, expected_root_tag)
      document = Nokogiri.XML(xml)
      if document.root.nil? || document.root.name != expected_root_tag
        raise ActiveShipping::ResponseContentError.new(StandardError.new('Invalid document'), xml)
      end
      document
    rescue Nokogiri::XML::SyntaxError => e
      raise ActiveShipping::ResponseContentError.new(e, xml)
    end

    def parse_rate_response(origin, destination, packages, response, options = {})
      xml = build_document(response, 'RatingServiceSelectionResponse')
      success = response_success?(xml)
      message = response_message(xml)

      if success
        rate_estimates = xml.root.css('> RatedShipment').map do |rated_shipment|
          service_code = rated_shipment.at('Service/Code').text
          days_to_delivery = rated_shipment.at('GuaranteedDaysToDelivery').text.to_i
          days_to_delivery = nil if days_to_delivery == 0
          RateEstimate.new(origin, destination, @@name, service_name_for(origin, service_code),
              :total_price => rated_shipment.at('TotalCharges/MonetaryValue').text.to_f,
              :insurance_price => rated_shipment.at('ServiceOptionsCharges/MonetaryValue').text.to_f,
              :currency => rated_shipment.at('TotalCharges/CurrencyCode').text,
              :service_code => service_code,
              :packages => packages,
              :delivery_range => [timestamp_from_business_day(days_to_delivery)],
              :negotiated_rate => rated_shipment.at('NegotiatedRates/NetSummaryCharges/GrandTotal/MonetaryValue').try(:text).to_f
          )
        end
      end
      RateResponse.new(success, message, Hash.from_xml(response).values.first, :rates => rate_estimates, :xml => response, :request => last_request)
    end

    def parse_tracking_response(response, options = {})
      xml     = build_document(response, 'TrackResponse')
      success = response_success?(xml)
      message = response_message(xml)

      if success
        delivery_signature = nil
        exception_event, scheduled_delivery_date, actual_delivery_date = nil
        delivered, exception = false
        shipment_events = []

        first_shipment = xml.root.at('Shipment')
        first_package = first_shipment.at('Package')
        tracking_number = first_shipment.at_xpath('ShipmentIdentificationNumber | Package/TrackingNumber').text

        # Build status hash
        status_nodes = first_package.css('Activity > Status > StatusType')

        # Prefer a delivery node
        status_node = status_nodes.detect { |x| x.at('Code').text == 'D' }
        status_node ||= status_nodes.first

        status_code = status_node.at('Code').text
        status_description = status_node.at('Description').text
        status = TRACKING_STATUS_CODES[status_code]

        if status_description =~ /out.*delivery/i
          status = :out_for_delivery
        end

        origin, destination = %w(Shipper ShipTo).map do |location|
          location_from_address_node(first_shipment.at("#{location}/Address"))
        end

        # Get scheduled delivery date
        unless status == :delivered
          scheduled_delivery_date = parse_ups_datetime(
            :date => first_shipment.at('ScheduledDeliveryDate'),
            :time => nil
            )
        end

        activities = first_package.css('> Activity')
        unless activities.empty?
          shipment_events = activities.map do |activity|
            description = activity.at('Status/StatusType/Description').text
            zoneless_time = parse_ups_datetime(:time => activity.at('Time'), :date => activity.at('Date'))
            location = location_from_address_node(activity.at('ActivityLocation/Address'))
            ShipmentEvent.new(description, zoneless_time, location)
          end

          shipment_events = shipment_events.sort_by(&:time)

          # UPS will sometimes archive a shipment, stripping all shipment activity except for the delivery
          # event (see test/fixtures/xml/delivered_shipment_without_events_tracking_response.xml for an example).
          # This adds an origin event to the shipment activity in such cases.
          if origin && !(shipment_events.count == 1 && status == :delivered)
            first_event = shipment_events[0]
            origin_event = ShipmentEvent.new(first_event.name, first_event.time, origin)

            if within_same_area?(origin, first_event.location)
              shipment_events[0] = origin_event
            else
              shipment_events.unshift(origin_event)
            end
          end

          # Has the shipment been delivered?
          if status == :delivered
            delivered_activity = activities.first
            delivery_signature = delivered_activity.at('ActivityLocation/SignedForByName').try(:text)
            if delivered_activity.at('Status/StatusType/Code').text == 'D'
              actual_delivery_date = parse_ups_datetime(:date => delivered_activity.at('Date'), :time => delivered_activity.at('Time'))
            end
            unless destination
              destination = shipment_events[-1].location
            end
            shipment_events[-1] = ShipmentEvent.new(shipment_events.last.name, shipment_events.last.time, destination)
          end
        end

      end
      TrackingResponse.new(success, message, Hash.from_xml(response).values.first,
                           :carrier => @@name,
                           :xml => response,
                           :request => last_request,
                           :status => status,
                           :status_code => status_code,
                           :status_description => status_description,
                           :delivery_signature => delivery_signature,
                           :scheduled_delivery_date => scheduled_delivery_date,
                           :actual_delivery_date => actual_delivery_date,
                           :shipment_events => shipment_events,
                           :delivered => delivered,
                           :exception => exception,
                           :exception_event => exception_event,
                           :origin => origin,
                           :destination => destination,
                           :tracking_number => tracking_number)
    end

    def location_from_address_node(address)
      return nil unless address
      Location.new(
        :country     => address.at('CountryCode').try(:text),
        :postal_code => address.at('PostalCode').try(:text),
        :province    => address.at('StateProvinceCode').try(:text),
        :city        => address.at('City').try(:text),
        :address1    => address.at('AddressLine1').try(:text),
        :address2    => address.at('AddressLine2').try(:text),
        :address3    => address.at('AddressLine3').try(:text)
      )
    end

    def parse_ups_datetime(options = {})
      time, date = options[:time].try(:text), options[:date].text
      if time.nil?
        hour, minute, second = 0
      else
        hour, minute, second = time.scan(/\d{2}/)
      end
      year, month, day = date[0..3], date[4..5], date[6..7]

      Time.utc(year, month, day, hour, minute, second)
    end

    def response_success?(document)
      document.root.at('Response/ResponseStatusCode').text == '1'
    end

    def response_message(document)
      document.root.at_xpath('Response/Error/ErrorDescription | Response/ResponseStatusDescription').text
    end

    def response_digest(xml)
      xml.root.at('ShipmentDigest').text
    end

    def parse_ship_confirm(response)
      build_document(response, 'ShipmentConfirmResponse')
    end

    def parse_ship_accept(response)
      xml     = build_document(response, 'ShipmentAcceptResponse')
      success = response_success?(xml)
      message = response_message(xml)

      LabelResponse.new(success, message, Hash.from_xml(response).values.first)
    end

    def commit(action, request, test = false)
      ssl_post("#{test ? TEST_URL : LIVE_URL}/#{RESOURCES[action]}", request)
    end

    def within_same_area?(origin, location)
      return false unless location
      matching_country_codes = origin.country_code(:alpha2) == location.country_code(:alpha2)
      matching_or_blank_city = location.city.blank? || location.city == origin.city
      matching_country_codes && matching_or_blank_city
    end

    def service_name_for(origin, code)
      origin = origin.country_code(:alpha2)

      name = case origin
      when "CA" then CANADA_ORIGIN_SERVICES[code]
      when "MX" then MEXICO_ORIGIN_SERVICES[code]
      when *EU_COUNTRY_CODES then EU_ORIGIN_SERVICES[code]
      end

      name ||= OTHER_NON_US_ORIGIN_SERVICES[code] unless name == 'US'
      name || DEFAULT_SERVICES[code]
    end
  end
end
