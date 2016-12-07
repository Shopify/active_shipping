# -*- encoding: utf-8 -*-

module ActiveShipping
  class UPS < Carrier
    self.retry_safe = true
    self.ssl_version = :TLSv1_2

    cattr_accessor :default_options
    cattr_reader :name
    @@name = "UPS"

    TEST_URL = 'https://wwwcie.ups.com'
    LIVE_URL = 'https://onlinetools.ups.com'

    RESOURCES = {
      :rates => 'ups.app/xml/Rate',
      :track => 'ups.app/xml/Track',
      :ship_confirm => 'ups.app/xml/ShipConfirm',
      :ship_accept => 'ups.app/xml/ShipAccept',
      :delivery_dates =>  'ups.app/xml/TimeInTransit',
      :void =>  'ups.app/xml/Void'
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
      "86" => "UPS Today Express Saver",
      "92" => "UPS SurePost (USPS) < 1lb",
      "93" => "UPS SurePost (USPS) > 1lb",
      "94" => "UPS SurePost (USPS) BPM",
      "95" => "UPS SurePost (USPS) Media",
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

    RETURN_SERVICE_CODES = {
      "2"  => "UPS Print and Mail (PNM)",
      "3"  => "UPS Return Service 1-Attempt (RS1)",
      "5"  => "UPS Return Service 3-Attempt (RS3)",
      "8"  => "UPS Electronic Return Label (ERL)",
      "9"  => "UPS Print Return Label (PRL)",
      "10" => "UPS Exchange Print Return Label",
      "11" => "UPS Pack & Collect Service 1-Attempt Box 1",
      "12" => "UPS Pack & Collect Service 1-Attempt Box 2",
      "13" => "UPS Pack & Collect Service 1-Attempt Box 3",
      "14" => "UPS Pack & Collect Service 1-Attempt Box 4",
      "15" => "UPS Pack & Collect Service 1-Attempt Box 5",
      "16" => "UPS Pack & Collect Service 3-Attempt Box 1",
      "17" => "UPS Pack & Collect Service 3-Attempt Box 2",
      "18" => "UPS Pack & Collect Service 3-Attempt Box 3",
      "19" => "UPS Pack & Collect Service 3-Attempt Box 4",
      "20" => "UPS Pack & Collect Service 3-Attempt Box 5",
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

    DEFAULT_SERVICE_NAME_TO_CODE = Hash[UPS::DEFAULT_SERVICES.to_a.map(&:reverse)]
    DEFAULT_SERVICE_NAME_TO_CODE['UPS 2nd Day Air'] = "02"
    DEFAULT_SERVICE_NAME_TO_CODE['UPS 3 Day Select'] = "12"
    DEFAULT_SERVICE_NAME_TO_CODE['UPS Next Day Air Early'] = "14"

    SHIPMENT_DELIVERY_CONFIRMATION_CODES = {
      delivery_confirmation_signature_required: 1,
      delivery_confirmation_adult_signature_required: 2
    }

    PACKAGE_DELIVERY_CONFIRMATION_CODES = {
      delivery_confirmation: 1,
      delivery_confirmation_signature_required: 2,
      delivery_confirmation_adult_signature_required: 3,
      usps_delivery_confirmation: 4
    }

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

    # Retrieves tracking information for a previous shipment
    #
    # @note Override with whatever you need to get a shipping label
    #
    # @param tracking_number [String] The unique identifier of the shipment to track.
    # @param options [Hash] Carrier-specific parameters.
    # @option options [Boolean] :mail_innovations Set this to true to track a Mail Innovations Package
    # @return [ActiveShipping::TrackingResponse] The response from the carrier. This
    #   response should a list of shipment tracking events if successful.
    def find_tracking_info(tracking_number, options = {})
      options = @options.merge(options)
      access_request = build_access_request
      tracking_request = build_tracking_request(tracking_number, options)
      response = commit(:track, save_request(access_request + tracking_request), options[:test])
      parse_tracking_response(response, options)
    end

    def create_shipment(origin, destination, packages, options = {})
      options = @options.merge(options)
      packages = Array(packages)
      access_request = build_access_request

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
      raise ActiveShipping::ResponseContentError, StandardError.new(message) unless success
      digest  = response_digest(xml)

      # STEP 2: Accept. Use shipment digest in first response to get the actual label.
      accept_request = build_accept_request(digest, options)
      logger.debug(accept_request) if logger

      accept_response = commit(:ship_accept, save_request(access_request + accept_request), (options[:test] || false))
      logger.debug(accept_response) if logger

      # ...finally, build a map from the response that contains
      # the label data and tracking information.
      parse_ship_accept(accept_response)
    end

    def get_delivery_date_estimates(origin, destination, packages, pickup_date=Date.current, options = {})
      origin, destination = upsified_location(origin), upsified_location(destination)
      options = @options.merge(options)
      packages = Array(packages)
      access_request = build_access_request
      dates_request = build_delivery_dates_request(origin, destination, packages, pickup_date, options)
      response = commit(:delivery_dates, save_request(access_request + dates_request), (options[:test] || false))
      parse_delivery_dates_response(origin, destination, packages, response, options)
    end

    def void_shipment(tracking, options={})
      options = @options.merge(options)
      access_request = build_access_request
      void_request = build_void_request(tracking)
      response = commit(:void, save_request(access_request + void_request), (options[:test] || false))
      parse_void_response(response, options)
    end

    def maximum_address_field_length
      # http://www.ups.com/worldshiphelp/WS12/ENU/AppHelp/CONNECT/Shipment_Data_Field_Descriptions.htm
      35
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
          xml.UserId(@options[:login])
          xml.Password(@options[:password])
        end
      end
      xml_builder.to_xml
    end

    # Builds an XML node to request UPS shipping rates for the given packages
    #
    # @param origin [ActiveShipping::Location] Where the shipment will originate from
    # @param destination [ActiveShipping::Location] Where the package will go
    # @param packages [Array<ActiveShipping::Package>] The list of packages that will
    #   be in the shipment
    # @options options [Hash] rate-specific options
    # @return [ActiveShipping::RateResponse] The response from the UPS, which
    #   includes 0 or more rate estimates for different shipping products
    #
    # options:
    # * service: name of the service
    # * pickup_type: symbol for PICKUP_CODES
    # * customer_classification: symbol for CUSTOMER_CLASSIFICATIONS
    # * shipper: who is sending the package and where it should be returned
    #     if it is undeliverable.
    # * imperial: if truthy, measurements will use the metric system
    # * negotiated_rates: if truthy, negotiated rates will be requested from
    #     UPS. Only valid if shipper account has negotiated rates.
    def build_rate_request(origin, destination, packages, options = {})
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.RatingServiceSelectionRequest do
          xml.Request do
            xml.RequestAction('Rate')
            xml.RequestOption((options[:service].nil?) ? 'Shop' : 'Rate')
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

            unless options[:service].nil?
              xml.Service do
                xml.Code(options[:service])
              end
            end

            Array(packages).each do |package|
              options[:imperial] ||= IMPERIAL_COUNTRIES.include?(origin.country_code(:alpha2))
              build_package_node(xml, package, options)
            end

            # not implemented:  * Shipment/ShipmentServiceOptions element
            if options[:negotiated_rates]
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
    # * origin_account: account number for the shipper
    # * customer_context: a "guid like substance" -- according to UPS
    # * shipper: who is sending the package and where it should be returned
    #     if it is undeliverable.
    # * ship_from: where the package is picked up.
    # * service_code: default to '03'
    # * saturday_delivery: any truthy value causes this element to exist
    # * optional_processing: 'validate' (blank) or 'nonvalidate' or blank
    # * paperless_invoice: set to truthy if using paperless invoice to ship internationally
    # * terms_of_shipment: used with paperless invoice to specify who pays duties and taxes
    # * reference_numbers: Array of hashes with :value => a reference number value and optionally :code => reference number type
    # * prepay: if truthy the shipper will be bill immediatly. Otherwise the shipper is billed when the label is used.
    # * negotiated_rates: if truthy negotiated rates will be requested from ups. Only valid if shipper account has negotiated rates.
    # * delivery_confirmation: Can be set to any key from SHIPMENT_DELIVERY_CONFIRMATION_CODES. Can also be set on package level via package.options
    # * bill_third_party: When truthy, bill an account other than the shipper's. Specified by billing_(account, zip and country)
    def build_shipment_request(origin, destination, packages, options={})
      packages = Array(packages)
      shipper = options[:shipper] || origin
      options[:international] = origin.country.name != destination.country.name
      options[:imperial] ||= IMPERIAL_COUNTRIES.include?(shipper.country_code(:alpha2))
      options[:return] = options[:return_service_code].present?
      options[:reason_for_export] ||= ("RETURN" if options[:return])

      if allow_package_level_reference_numbers(origin, destination)
        if options[:reference_numbers]
          packages.each do |package|
            package.options[:reference_numbers] = options[:reference_numbers]
          end
        end
        options[:reference_numbers] = []
      end

      handle_delivery_confirmation_options(origin, destination, packages, options)

      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.ShipmentConfirmRequest do
          xml.Request do
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
            xml.Service do
              xml.Code(options[:service_code] || '03')
            end

            build_location_node(xml, 'ShipTo', destination, options)
            build_location_node(xml, 'ShipFrom', origin, options)
            # Required element. The company whose account is responsible for the label(s).
            build_location_node(xml, 'Shipper', shipper, options)

            if options[:saturday_delivery]
              xml.ShipmentServiceOptions do
                xml.SaturdayDelivery
              end
            end

            if options[:negotiated_rates]
              xml.RateInformation do
                xml.NegotiatedRatesIndicator
              end
            end

            Array(options[:reference_numbers]).each do |reference_num_info|
              xml.ReferenceNumber do
                xml.Code(reference_num_info[:code] || "")
                xml.Value(reference_num_info[:value])
              end
            end

            if options[:prepay]
              xml.PaymentInformation do
                xml.Prepaid do
                  build_billing_info_node(xml, options)
                end
              end
            else
              xml.ItemizedPaymentInformation do
                xml.ShipmentCharge do
                  # Type '01' means 'Transportation'
                  # This node specifies who will be billed for transportation.
                  xml.Type('01')
                  build_billing_info_node(xml, options)
                end
                if options[:terms_of_shipment] == 'DDP' && options[:international]
                  # DDP stands for delivery duty paid and means the shipper will cover duties and taxes
                  # Otherwise UPS will charge the receiver
                  xml.ShipmentCharge do
                    xml.Type('02') # Type '02' means 'Duties and Taxes'
                    build_billing_info_node(xml, options.merge(bill_to_consignee: true))
                  end
                end
              end
            end

            if options[:international]
              unless options[:return]
                build_location_node(xml, 'SoldTo', options[:sold_to] || destination, options)
              end

              if origin.country_code(:alpha2) == 'US' && ['CA', 'PR'].include?(destination.country_code(:alpha2))
                # Required for shipments from the US to Puerto Rico or Canada
                xml.InvoiceLineTotal do
                  total_value = packages.inject(0) {|sum, package| sum + (package.value || 0)}
                  xml.MonetaryValue(total_value)
                end
              end

              contents_description = packages.map {|p| p.options[:description]}.compact.join(',')
              unless contents_description.empty?
                xml.Description(contents_description)
              end
            end

            if options[:return]
              xml.ReturnService do
                xml.Code(options[:return_service_code])
              end
            end

            xml.ShipmentServiceOptions do
              if delivery_confirmation = options[:delivery_confirmation]
                xml.DeliveryConfirmation do
                  xml.DCISType(SHIPMENT_DELIVERY_CONFIRMATION_CODES[delivery_confirmation])
                end
              end

              if options[:international]
                build_international_forms(xml, origin, destination, packages, options)
              end
            end

            # A request may specify multiple packages.
            packages.each do |package|
              build_package_node(xml, package, options)
            end
          end

          # Supported label formats:
          # GIF, EPL, ZPL, STARPL and SPL
          label_format = options[:label_format] ? options[:label_format].upcase : 'GIF'
          label_size = options[:label_size] ? options[:label_size] : [4, 6]

          xml.LabelSpecification do
            xml.LabelStockSize do
              xml.Height(label_size[0])
              xml.Width(label_size[1])
            end

            xml.LabelPrintMethod do
              xml.Code(label_format)
            end

            # API requires these only if returning a GIF formated label
            if label_format == 'GIF'
              xml.HTTPUserAgent('Mozilla/4.5')
              xml.LabelImageFormat(label_format) do
                xml.Code(label_format)
              end
            end
          end
        end
      end
      xml_builder.to_xml
    end

    def build_delivery_dates_request(origin, destination, packages, pickup_date, options={})
      xml_builder = Nokogiri::XML::Builder.new do |xml|

        xml.TimeInTransitRequest do
          xml.Request do
            xml.RequestAction('TimeInTransit')
          end

          build_address_artifact_format_location(xml, 'TransitFrom', origin)
          build_address_artifact_format_location(xml, 'TransitTo', destination)

          xml.ShipmentWeight do
            xml.UnitOfMeasurement do
              xml.Code(options[:imperial] ? 'LBS' : 'KGS')
            end

            value = packages.inject(0) do |sum, package|
              sum + (options[:imperial] ? package.lbs.to_f : package.kgs.to_f )
            end

            xml.Weight([value.round(3), 0.1].max)
          end

          if packages.any? {|package| package.value.present?}
            xml.InvoiceLineTotal do
              xml.CurrencyCode('USD')
              total_value = packages.inject(0) {|sum, package| sum + package.value.to_i}
              xml.MonetaryValue(total_value)
            end
          end

          xml.PickupDate(pickup_date.strftime('%Y%m%d'))
        end
      end

      xml_builder.to_xml
    end

    def build_void_request(tracking)
      xml_builder = Nokogiri::XML::Builder.new do |xml|
        xml.VoidShipmentRequest do
          xml.Request do
            xml.RequestAction('Void')
          end
          xml.ShipmentIdentificationNumber(tracking)
        end
      end
      xml_builder.to_xml
    end

    def build_international_forms(xml, origin, destination, packages, options)
      if options[:paperless_invoice]
        xml.InternationalForms do
          xml.FormType('01') # 01 is "Invoice"
          xml.InvoiceDate(options[:invoice_date] || Date.today.strftime('%Y%m%d'))
          xml.ReasonForExport(options[:reason_for_export] || 'SALE')
          xml.CurrencyCode(options[:currency_code] || 'USD')

          if options[:terms_of_shipment]
            xml.TermsOfShipment(options[:terms_of_shipment])
          end

          packages.each do |package|
            xml.Product do |xml|
              xml.Description(package.options[:description])
              xml.CommodityCode(package.options[:commodity_code])
              xml.OriginCountryCode(origin.country_code(:alpha2))
              xml.Unit do |xml|
                xml.Value(package.value / (package.options[:item_count] || 1))
                xml.Number((package.options[:item_count] || 1))
                xml.UnitOfMeasurement do |xml|
                  # NMB = number. You can specify units in barrels, boxes, etc. Codes are in the api docs.
                  xml.Code(package.options[:unit_of_item_count] || 'NMB')
                end
              end
            end
          end
        end
      end
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
          xml.TrackingOption(options[:tracking_option]) if options[:tracking_option]
          xml.Request do
            xml.RequestAction('Track')
            xml.RequestOption('1')
          end
          xml.TrackingNumber(tracking_number.to_s)
          xml.TrackingOption('03') if options[:mail_innovations]
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
        if shipper_name = (location.name || location.company_name || options[:origin_name])
          xml.Name(shipper_name)
        end
        xml.PhoneNumber(location.phone.gsub(/[^\d]/, '')) unless location.phone.blank?
        xml.FaxNumber(location.fax.gsub(/[^\d]/, '')) unless location.fax.blank?

        if name == 'Shipper' and (origin_account = options[:origin_account] || @options[:origin_account])
          xml.ShipperNumber(origin_account)
        elsif name == 'ShipTo' and (destination_account = options[:destination_account] || @options[:destination_account])
          xml.ShipperAssignedIdentificationNumber(destination_account)
        end

        if name = (location.company_name || location.name || options[:origin_name])
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

    def build_address_artifact_format_location(xml, name, location)
      xml.public_send(name) do
        xml.AddressArtifactFormat do
          xml.PoliticalDivision2(location.city)
          xml.PoliticalDivision1(location.province)
          xml.CountryCode(location.country_code(:alpha2))
          xml.PostcodePrimaryLow(location.postal_code)
          xml.ResidentialAddressIndicator(true) unless location.commercial?
        end
      end
    end

    def build_package_node(xml, package, options = {})
      xml.Package do
        # not implemented:  * Shipment/Package/PackagingType element

        #return requires description
        if options[:return]
          contents_description = package.options[:description]
          xml.Description(contents_description) if contents_description
        end

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
          if (options[:service] || options[:service_code]) == DEFAULT_SERVICE_NAME_TO_CODE["UPS SurePost (USPS) < 1lb"]
            # SurePost < 1lb uses OZS, not LBS
            code = options[:imperial] ? 'OZS' : 'KGS'
            weight = options[:imperial] ? package.oz : package.kgs
          else
            code = options[:imperial] ? 'LBS' : 'KGS'
            weight = options[:imperial] ? package.lbs : package.kgs
          end
          xml.UnitOfMeasurement do
            xml.Code(code)
          end

          value = ((weight).to_f * 1000).round / 1000.0 # 3 decimals
          xml.Weight([value, 0.1].max)
        end


        Array(package.options[:reference_numbers]).each do |reference_number_info|
          xml.ReferenceNumber do
            xml.Code(reference_number_info[:code] || "")
            xml.Value(reference_number_info[:value])
          end
        end

        xml.PackageServiceOptions do
          if delivery_confirmation = package.options[:delivery_confirmation]
            xml.DeliveryConfirmation do
              xml.DCISType(PACKAGE_DELIVERY_CONFIRMATION_CODES[delivery_confirmation])
            end
          end

          if dry_ice = package.options[:dry_ice]
            xml.DryIce do
              xml.RegulationSet(dry_ice[:regulation_set] || 'CFR')
              xml.DryIceWeight do
                xml.UnitOfMeasurement do
                  xml.Code(options[:imperial] ? 'LBS' : 'KGS')
                end
                # Cannot be more than package weight.
                # Should be more than 0.0.
                # Valid characters are 0-9 and .(Decimal point).
                # Limit to 1 digit after the decimal. The maximum length
                # of the field is 5 including . and can hold up
                # to 1 decimal place.
                xml.Weight(dry_ice[:weight])
              end
            end
          end

          if package_value = package.options[:insured_value]
            xml.InsuredValue do
              xml.CurrencyCode(package.options[:currency] || 'USD')
              xml.MonetaryValue(package_value.to_f)
            end
          end
        end

        # not implemented:  * Shipment/Package/LargePackageIndicator element
        #                   * Shipment/Package/AdditionalHandling element
      end
    end

    def build_billing_info_node(xml, options={})
      if options[:bill_third_party]
        xml.BillThirdParty do
          node_type = options[:bill_to_consignee] ? :BillThirdPartyConsignee : :BillThirdPartyShipper
          xml.public_send(node_type) do
            xml.AccountNumber(options[:billing_account])
            xml.ThirdParty do
              xml.Address do
                xml.PostalCode(options[:billing_zip])
                xml.CountryCode(options[:billing_country])
              end
            end
          end
        end
      else
        xml.BillShipper do
          xml.AccountNumber(options[:origin_account])
        end
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
          warning_messages = rate_warning_messages(rated_shipment)
          RateEstimate.new(origin, destination, @@name, service_name_for(origin, service_code),
              :total_price => rated_shipment.at('TotalCharges/MonetaryValue').text.to_f,
              :insurance_price => rated_shipment.at('ServiceOptionsCharges/MonetaryValue').text.to_f,
              :currency => rated_shipment.at('TotalCharges/CurrencyCode').text,
              :service_code => service_code,
              :packages => packages,
              :delivery_range => [timestamp_from_business_day(days_to_delivery)],
              :negotiated_rate => rated_shipment.at('NegotiatedRates/NetSummaryCharges/GrandTotal/MonetaryValue').try(:text).to_f,
              :messages => warning_messages
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

        if status_nodes.present?
          # Prefer a delivery node
          status_node = status_nodes.detect { |x| x.at('Code').text == 'D' }
          status_node ||= status_nodes.first

          status_code = status_node.at('Code').try(:text)
          status_description = status_node.at('Description').try(:text)
          status = TRACKING_STATUS_CODES[status_code]

          if status_description =~ /out.*delivery/i
            status = :out_for_delivery
          end
        end

        origin, destination = %w(Shipper ShipTo).map do |location|
          location_from_address_node(first_shipment.at("#{location}/Address"))
        end

        # Get scheduled delivery date
        unless status == :delivered
          scheduled_delivery_date_node = first_shipment.at('ScheduledDeliveryDate')
          scheduled_delivery_date_node ||= first_shipment.at('RescheduledDeliveryDate')

          if scheduled_delivery_date_node
            scheduled_delivery_date = parse_ups_datetime(
              :date => scheduled_delivery_date_node,
              :time => nil
              )
          end
        end

        activities = first_package.css('> Activity')
        unless activities.empty?
          shipment_events = activities.map do |activity|
            description = activity.at('Status/StatusType/Description').try(:text)
            type_code = activity.at('Status/StatusType/Code').try(:text)
            zoneless_time = parse_ups_datetime(:time => activity.at('Time'), :date => activity.at('Date'))
            location = location_from_address_node(activity.at('ActivityLocation/Address'))
            ShipmentEvent.new(description, zoneless_time, location, description, type_code)
          end

          shipment_events = shipment_events.sort_by(&:time)

          # UPS will sometimes archive a shipment, stripping all shipment activity except for the delivery
          # event (see test/fixtures/xml/delivered_shipment_without_events_tracking_response.xml for an example).
          # This adds an origin event to the shipment activity in such cases.
          if origin && !(shipment_events.count == 1 && status == :delivered)
            first_event = shipment_events[0]
            origin_event = ShipmentEvent.new(first_event.name, first_event.time, origin, first_event.message, first_event.type_code)

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
            shipment_events[-1] = ShipmentEvent.new(shipment_events.last.name, shipment_events.last.time, destination, shipment_events.last.message, shipment_events.last.type_code)
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

    def parse_delivery_dates_response(origin, destination, packages, response, options={})
      xml     = build_document(response, 'TimeInTransitResponse')
      success = response_success?(xml)
      message = response_message(xml)
      delivery_estimates = []

      if success
        xml.css('ServiceSummary').each do |service_summary|
          # Translate the Time in Transit Codes to the service codes used elsewhere
          service_name = service_summary.at('Service/Description').text
          service_code = UPS::DEFAULT_SERVICE_NAME_TO_CODE[service_name]
          date = Date.strptime(service_summary.at('EstimatedArrival/Date').text, '%Y-%m-%d')
          business_transit_days = service_summary.at('EstimatedArrival/BusinessTransitDays').text.to_i
          delivery_estimates << DeliveryDateEstimate.new(origin, destination, self.class.class_variable_get(:@@name),
                                    service_name,
                                    :service_code => service_code,
                                    :guaranteed => service_summary.at('Guaranteed/Code').text == 'Y',
                                    :date =>  date,
                                    :business_transit_days => business_transit_days)
        end
      end
      response = DeliveryDateEstimatesResponse.new(success, message, Hash.from_xml(response).values.first, :delivery_estimates => delivery_estimates, :xml => response, :request => last_request)
    end

    def parse_void_response(response, options={})
      xml = build_document(response, 'VoidShipmentResponse')
      success = response_success?(xml)
      message = response_message(xml)
      if success
        true
      else
        raise ResponseError.new("Void shipment failed with message: #{message}")
      end
    end

    def location_from_address_node(address)
      return nil unless address
      country = address.at('CountryCode').try(:text)
      country = 'US' if country == 'ZZ' # Sometimes returned by SUREPOST in the US
      Location.new(
        :country     => country,
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
      status = document.root.at_xpath('Response/ResponseStatusDescription').try(:text)
      desc = document.root.at_xpath('Response/Error/ErrorDescription').try(:text)
      [status, desc].select(&:present?).join(": ").presence || "UPS could not process the request."
    end

    def rate_warning_messages(rate_xml)
      rate_xml.xpath("RatedShipmentWarning").map { |warning| warning.text }
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

      response_info = Hash.from_xml(response).values.first
      packages = response_info["ShipmentResults"]["PackageResults"]
      packages = [packages] if Hash === packages
      labels = packages.map do |package|
        Label.new(package["TrackingNumber"], Base64.decode64(package["LabelImage"]["GraphicImage"]))
      end

      LabelResponse.new(success, message, response_info, {labels: labels})
    end

    def commit(action, request, test = false)
      response = ssl_post("#{test ? TEST_URL : LIVE_URL}/#{RESOURCES[action]}", request)
      response.encode('utf-8', 'iso-8859-1')
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

    def allow_package_level_reference_numbers(origin, destination)
      # if the package is US -> US or PR -> PR the only type of reference numbers that are allowed are package-level
      # Otherwise the only type of reference numbers that are allowed are shipment-level
      [['US','US'],['PR', 'PR']].include?([origin,destination].map(&:country_code))
    end

    def handle_delivery_confirmation_options(origin, destination, packages, options)
      if package_level_delivery_confirmation?(origin, destination)
        handle_package_level_delivery_confirmation(origin, destination, packages, options)
      else
        handle_shipment_level_delivery_confirmation(origin, destination, packages, options)
      end
    end

    def handle_package_level_delivery_confirmation(origin, destination, packages, options)
      packages.each do |package|
        # Transfer shipment-level option to package with no specified delivery_confirmation
        package.options[:delivery_confirmation] = options[:delivery_confirmation] unless package.options[:delivery_confirmation]

        # Assert that option is valid
        if package.options[:delivery_confirmation] && !PACKAGE_DELIVERY_CONFIRMATION_CODES[package.options[:delivery_confirmation]]
          raise "Invalid delivery_confirmation option on package: '#{package.options[:delivery_confirmation]}'. Use a key from PACKAGE_DELIVERY_CONFIRMATION_CODES"
        end
      end
      options.delete(:delivery_confirmation)
    end

    def handle_shipment_level_delivery_confirmation(origin, destination, packages, options)
      if packages.any? { |p| p.options[:delivery_confirmation] }
        raise "origin/destination pair does not support package level delivery_confirmation options"
      end

      if options[:delivery_confirmation] && !SHIPMENT_DELIVERY_CONFIRMATION_CODES[options[:delivery_confirmation]]
        raise "Invalid delivery_confirmation option: '#{options[:delivery_confirmation]}'. Use a key from SHIPMENT_DELIVERY_CONFIRMATION_CODES"
      end
    end

    # For certain origin/destination pairs, UPS allows each package in a shipment to have a specified delivery_confirmation option
    # otherwise the delivery_confirmation option must be specified on the entire shipment.
    # See Appendix P of UPS Shipping Package XML Developers Guide for the rules on which the logic below is based.
    def package_level_delivery_confirmation?(origin, destination)
      origin.country_code == destination.country_code ||
      [['US','PR'], ['PR','US']].include?([origin,destination].map(&:country_code))
    end
  end
end
