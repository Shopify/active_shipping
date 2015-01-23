module ActiveShipping
  # Stamps.com integration for rating, tracking, address validation, and label generation
  # Integration ID can be requested from Stamps.com

  class Stamps < Carrier
    cattr_reader :name
    @@name = 'Stamps'

    attr_reader :last_swsim_method

    # TODO: Update to latest API. Documentation for the latest WSDL version is available here: http://support.stamps.com/outgoing/swsimv39doc.zip
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

    US_POSSESSIONS = %w(AS FM GU MH MP PW PR VI)

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

    CARRIER_PICKUP_LOCATION = {
      'FrontDoor'             => 'Packages are at front door',
      'BackDoor'              => 'Packages are at back door',
      'SideDoor'              => 'Packages are at side door',
      'KnockOnDoorOrRingBell' => 'Knock on door or ring bell',
      'MailRoom'              => 'Packages are in mail room',
      'Office'                => 'Packages are in office',
      'Reception'             => 'Packages are at reception area',
      'InOrAtMailbox'         => 'Packages are in mail box',
      'Other'                 => 'Other Location'
    }

    PRINT_LAYOUTS = [
      'Normal',
      'NormalLeft',
      'NormalRight',
      'Normal4X6',
      'Normal6X4',
      'Normal75X2',
      'NormalReceipt',
      'NormalCN22',
      'NormalCP72',
      'Normal4X6CN22',
      'Normal6X4CN22',
      'Normal4X6CP72',
      'Normal6X4CP72',
      'Normal4X675',
      'Normal4X675CN22',
      'Normal4X675CP72',
      'Return',
      'ReturnCN22',
      'ReturnCP72',
      'Return4X675',
      'Return4X675CN22',
      'Return4X675CP72',
      'SDC3510',
      'SDC3520',
      'SDC3530',
      'SDC3610',
      'SDC3710',
      'SDC3810',
      'SDC3820',
      'SDC3910',
      'Envelope9',
      'Envelope10',
      'Envelope11',
      'Envelope12',
      'EnvelopePersonal',
      'EnvelopeMonarch',
      'EnvelopeInvitation',
      'EnvelopeGreeting'
    ]

    IMAGE_TYPE = %w(Auto Epl Gif Jpg Pdf Png Zpl)

    def account_info
      request = build_get_account_info_request
      commit(:GetAccountInfo, request)
    end

    def purchase_postage(purchase_amount, control_total)
      request = build_purchase_postage_request(purchase_amount, control_total)
      commit(:PurchasePostage, request)
    end

    def purchase_status(transaction_id)
      request = build_get_purchase_status(transaction_id)
      commit(:GetPurchaseStatus, request)
    end

    def validate_address(address, options = {})
      address = standardize_address(address)
      request = build_cleanse_address_request(address)
      commit(:CleanseAddress, request)
    end

    def find_rates(origin, destination, package, options = {})
      origin = standardize_address(origin)
      destination = standardize_address(destination)
      request = build_rate_request(origin, destination, package, options)
      commit(:GetRates, request)
    end

    def create_shipment(origin, destination, package, line_items = [], options = {})
      origin = standardize_address(origin)
      destination = standardize_address(destination)
      request = build_create_indicium_request(origin, destination, package, line_items, options)
      commit(:CreateIndicium, request)
    end

    def find_tracking_info(shipment_id, options = {})
      request = build_track_shipment_request(shipment_id, options)
      commit(:TrackShipment, request)
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
      commit(:AuthenticateUser, request)
    end

    def build_header
      Nokogiri::XML::Builder.new do |xml|
        xml['soap'].Envelope(
                 'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
                 'xmlns:xsi'  => 'http://www.w3.org/2001/XMLSchema-instance',
                 'xmlns:xsd'  => 'http://www.w3.org/2001/XMLSchema',
                 'xmlns:tns'  => 'http://stamps.com/xml/namespace/2014/01/swsim/swsimv34'
                ) do
          xml['soap'].Body do
            yield(xml)
          end
        end
      end.to_xml
    end

    def build_authenticate_user_request
      build_header do |xml|
        xml['tns'].AuthenticateUser do
          xml['tns'].Credentials do
            xml['tns'].IntegrationID(@options[:integration_id])
            xml['tns'].Username(@options[:username])
            xml['tns'].Password(@options[:password])
          end
        end
      end
    end

    def build_get_account_info_request
      build_header do |xml|
        xml['tns'].GetAccountInfo do
          xml['tns'].Authenticator(authenticator)
        end
      end
    end

    def build_purchase_postage_request(purchase_amount, control_total)
      build_header do |xml|
        xml['tns'].PurchasePostage do
          xml['tns'].Authenticator(authenticator)
          xml['tns'].PurchaseAmount(purchase_amount)
          xml['tns'].ControlTotal(control_total)
        end
      end
    end

    def build_get_purchase_status(transaction_id)
      build_header do |xml|
        xml['tns'].GetPurchaseStatus do
          xml['tns'].Authenticator(authenticator)
          xml['tns'].TransactionID(transaction_id)
        end
      end
    end

    def build_cleanse_address_request(address)
      build_header do |xml|
        xml['tns'].CleanseAddress do
          xml['tns'].Authenticator(authenticator)
          add_address(xml, address)
        end
      end
    end

    def add_address(xml, address, object_type = :Address)
      xml['tns'].public_send(object_type) do
        xml['tns'].FullName(      address.name) unless address.name.blank?
        xml['tns'].Company(       address.company) unless address.company.blank?
        xml['tns'].Address1(      address.address1)
        xml['tns'].Address2(      address.address2) unless address.address2.blank?
        xml['tns'].Address3(      address.address3) unless address.address3.blank?
        xml['tns'].City(          address.city) unless address.city.blank?
        if domestic?(address)
          xml['tns'].State(       address.state) unless address.state.blank?

          zip = (address.postal_code || '').match(/^(\d{5})?-?(\d{4})?$/)
          xml['tns'].ZIPCode(     zip[1]) unless zip[1].nil?
          xml['tns'].ZIPCodeAddOn(zip[2]) unless zip[2].nil?
        else
          xml['tns'].Province(    address.province) unless address.province.blank?
          xml['tns'].PostalCode(  address.postal_code) unless address.postal_code.blank?
        end
        xml['tns'].Country(       address.country_code) unless address.country_code.blank?
        xml['tns'].PhoneNumber(   address.phone) unless address.phone.blank?
      end
    end

    def build_rate_request(origin, destination, package, options)
      build_header do |xml|
        xml['tns'].GetRates do
          xml['tns'].Authenticator(authenticator)
          add_rate(xml, origin, destination, package, options)
        end
      end
    end

    def add_rate(xml, origin, destination, package, options)
      value = package.value ? '%.2f' % (package.value.to_f / 100) : nil
      options[:insured_value] ||= value
      options[:declared_value] ||= value if international?(destination)

      xml['tns'].Rate do
        xml['tns'].FromZIPCode(      origin.postal_code) unless origin.postal_code.blank?
        xml['tns'].ToZIPCode(        destination.postal_code) unless destination.postal_code.blank?
        xml['tns'].ToCountry(        destination.country_code) unless destination.country_code.blank?
        xml['tns'].ServiceType(      options[:service]) unless options[:service].blank?
        xml['tns'].PrintLayout(      options[:print_layout]) unless options[:print_layout].blank?
        xml['tns'].WeightOz(         [package.ounces, 1].max)
        xml['tns'].PackageType(      options[:package_type] || 'Package')
        xml['tns'].Length(           package.inches(:length)) if package.inches(:length)
        xml['tns'].Width(            package.inches(:width)) if package.inches(:width)
        xml['tns'].Height(           package.inches(:height)) if package.inches(:height)
        xml['tns'].ShipDate(         options[:ship_date] || Date.today)
        xml['tns'].InsuredValue(     options[:insured_value]) unless options[:insured_value].blank?
        xml['tns'].CODValue(         options[:cod_value]) unless options[:cod_value].blank?
        xml['tns'].DeclaredValue(    options[:declared_value]) unless options[:declared_value].blank?

        machinable = if package.options.has_key?(:machinable)
          package.options[:machinable] ? true : false
        else
          USPS.package_machinable?(package)
        end

        xml['tns'].NonMachinable(    true) unless machinable

        xml['tns'].RectangularShaped(!package.cylinder?)
        xml['tns'].GEMNotes(         options[:gem_notes]) unless options[:gem_notes].blank?

        add_ons = Array(options[:add_ons])
        unless add_ons.empty?
          xml['tns'].AddOns do
            add_ons.each do |add_on|
              xml['tns'].AddOnV5 do
                xml['tns'].AddOnType(add_on)
              end
            end
          end
        end

        xml['tns'].ToState(destination.province) unless destination.province.blank?
      end
    end

    def build_create_indicium_request(origin, destination, package, line_items, options)
      build_header do |xml|
        xml['tns'].CreateIndicium do
          xml['tns'].Authenticator(            authenticator)
          xml['tns'].IntegratorTxID(           options[:integrator_tx_id] || SecureRandom::uuid)

          add_rate(xml, origin, destination, package, options)
          add_address(xml, origin, :From)
          add_address(xml, destination, :To)
          add_customs(xml, line_items, options) unless options[:content_type].blank?

          xml['tns'].SampleOnly(               options[:sample_only]) unless options[:sample_only].blank?
          xml['tns'].ImageType(                options[:image_type]) unless options[:image_type].blank?
          xml['tns'].EltronPrinterDPIType(     options[:label_resolution]) unless options[:label_resolution].blank?
          xml['tns'].memo(                     options[:memo]) unless options[:memo].blank?
          xml['tns'].deliveryNotification(     options[:delivery_notification]) unless options[:delivery_notification].blank?

          add_shipment_notification(xml, options) unless options[:email].blank?

          xml['tns'].horizontalOffset(         options[:horizontal_offset]) unless options[:horizontal_offest].blank?
          xml['tns'].verticalOffset(           options[:vertical_offset]) unless options[:vertical_offest].blank?
          xml['tns'].printDensity(             options[:print_density]) unless options[:print_density].blank?
          xml['tns'].rotationDegrees(          options[:rotation]) unless options[:rotation].blank?
          xml['tns'].printMemo(                options[:print_memo]) unless options[:print_memo].blank?
          xml['tns'].printInstructions(        options[:print_instructions]) unless options[:print_instructions].blank?
          xml['tns'].ReturnImageData(          options[:return_image_data]) unless options[:return_image_data].blank?
          xml['tns'].InternalTransactionNumber(options[:internal_transaction_number]) unless options[:internal_transaction_number].blank?
          xml['tns'].PaperSize(                options[:paper_size]) unless options[:paper_size].blank?

          add_label_recipient_info(xml, options) unless options[:label_email_address].blank?
        end
      end
    end

    def add_shipment_notification(xml, options)
      xml['tns'].ShipmentNotification do
        xml['tns'].Email(                   options[:email])
        xml['tns'].CCToAccountHolder(       options[:cc_to_account_holder]) unless options[:cc_to_account_holder].blank?
        xml['tns'].UseCompanyNameInFromLine(options[:use_company_name_in_from_name]) unless options[:use_company_name_in_from_line].blank?
        xml['tns'].UseCompanyNameInSubject( options[:use_company_name_in_subject]) unless options[:use_company_name_in_subject].blank?
      end
    end

    def add_customs(xml, line_items, options)
      xml['tns'].Customs do
        xml['tns'].ContentType(      options[:content_type])
        xml['tns'].Comments(         options[:comments]) unless options[:comments].blank?
        xml['tns'].LicenseNumber(    options[:license_number]) unless options[:license_number].blank?
        xml['tns'].CertificateNumber(options[:certificate_number]) unless options[:certificate_number].blank?
        xml['tns'].InvoiceNumber(    options[:invoice_number]) unless options[:invoice_number].blank?
        xml['tns'].OtherDescribe(    options[:other_describe]) unless options[:other_describe].blank?

        xml['tns'].CustomsLines do
          line_items.each do |customs_line|
            xml['tns'].CustomsLine do
              xml['tns'].Description(    customs_line.name)
              xml['tns'].Quantity(       customs_line.quantity)
              xml['tns'].Value(          '%.2f' % (customs_line.value.to_f / 100))
              xml['tns'].WeightOz(       customs_line.ounces) unless customs_line.ounces.blank?
              xml['tns'].HSTariffNumber( customs_line.hs_code.tr('.', '')[0..5]) unless customs_line.hs_code.blank?
              xml['tns'].CountryOfOrigin(customs_line.options[:country]) unless customs_line.options[:country].blank?
            end
          end
        end
      end
    end

    def add_label_recipient_info(xml, options)
      xml['tns'].LabelRecipientInfo do
        xml['tns'].EmailAddress(    options[:label_email_address])
        xml['tns'].Name(            options[:name]) unless options[:name].blank?
        xml['tns'].Note(            options[:note]) unless options[:note].blank?
        xml['tns'].CopyToOriginator(options[:copy_to_originator]) unless options[:copy_to_originator].blank?
      end
    end

    def build_track_shipment_request(shipment_id, options)
      build_header do |xml|
        xml['tns'].TrackShipment do
          xml['tns'].Authenticator(authenticator)
          xml['tns'].public_send(options[:stamps_tx_id] ? :StampsTxID : :TrackingNumber, shipment_id)
        end
      end
    end

    def commit(swsim_method, request)
      save_request(request)
      save_swsim_method(swsim_method)
      parse(ssl_post(request_url, request, 'Content-Type' => 'text/xml', 'SOAPAction' => soap_action(swsim_method)))
    rescue ActiveUtils::ResponseError => e
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

      # Renew the Authenticator if it has expired and retry the request
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

    def parse_purchase_postage_response(postage, response_options)
      parse_authenticator(postage)

      response_options[:purchase_status]   = postage.get_text('PurchaseStatus').to_s
      response_options[:rejection_reason]  = postage.get_text('RejectionReason').to_s if postage.get_text('RejectionReason')
      response_options[:transaction_id]    = postage.get_text('TransactionID').to_s if postage.get_text('TransactionID')

      balance = postage.elements['PostageBalance']
      response_options[:available_postage] = balance.get_text('AvailablePostage').to_s
      response_options[:control_total]     = balance.get_text('ControlTotal').to_s if balance.get_text('ControlTotal')

      StampsPurchasePostageResponse.new(true, '', {}, response_options)
    end
    alias_method :parse_get_purchase_status_response, :parse_purchase_postage_response

    def parse_cleanse_address_response(cleanse_address, response_options)
      parse_authenticator(cleanse_address)

      response_options[:address_match]     = cleanse_address.get_text('AddressMatch').to_s == 'true'
      response_options[:city_state_zip_ok] = cleanse_address.get_text('CityStateZipOK').to_s == 'true'

      address = cleanse_address.elements['Address']
      response_options[:cleanse_hash]  = address.get_text('CleanseHash').to_s if address.get_text('CleanseHash')
      response_options[:override_hash] = address.get_text('OverrideHash').to_s if address.get_text('OverrideHash')

      address_node = cleanse_address.elements['Address']
      indicator_node = cleanse_address.get_text('ResidentialDeliveryIndicatorType').to_s
      po_box_node    = cleanse_address.get_text('IsPOBox').to_s
      response_options[:address] = parse_address(address_node, indicator_node, po_box_node)

      candidate_addresses = cleanse_address.get_elements('CandidateAddresses/Address')
      response_options[:candidate_addresses] = candidate_addresses.map do |candidate_address|
        parse_address(candidate_address)
      end

      StampsCleanseAddressResponse.new(true, '', {}, response_options)
    end

    def parse_address(address_node, residential_indicator_node = nil, po_box_node = nil)
      address = {}

      address[:name]     = address_node.get_text('FullName').to_s if address_node.get_text('FullName')
      address[:company]  = address_node.get_text('Company').to_s if address_node.get_text('Company')
      address[:address1] = address_node.get_text('Address1').to_s if address_node.get_text('Address1')
      address[:address2] = address_node.get_text('Address2').to_s if address_node.get_text('Address2')
      address[:address3] = address_node.get_text('Address3').to_s if address_node.get_text('Address3')
      address[:city]     = address_node.get_text('City').to_s if address_node.get_text('City')
      address[:country]  = address_node.get_text('Country').to_s if address_node.get_text('Country')
      address[:phone]    = address_node.get_text('PhoneNumber').to_s if address_node.get_text('PhoneNumber')

      if address[:country] == 'US' || address[:country].nil?
        address[:state]  = address_node.get_text('State').to_s if address_node.get_text('State')

        address[:postal_code] = address_node.get_text('ZIPCode').to_s if address_node.get_text('ZIPCode')
        address[:postal_code] += '-' + address_node.get_text('ZIPCodeAddOn').to_s if address_node.get_text('ZIPCodeAddOn')
      else
        address[:province]    = address_node.get_text('Province').to_s if address_node.get_text('Province')
        address[:postal_code] = address_node.get_text('PostalCode').to_s if address_node.get_text('PostalCode')
      end

      address[:address_type] = if residential_indicator_node == 'Yes'
        'residential'
      elsif residential_indicator_node == 'No'
        'commercial'
      elsif po_box_node == 'true'
        'po_box'
      else
        nil
      end

      Location.new(address)
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

        prohibited_with = add_on.get_elements('ProhibitedWithAnyOf/AddOnTypeV5').map(&:text)
        add_on_details[:prohibited_with] = prohibited_with unless prohibited_with.empty?

        add_ons[add_on_type] = add_on_details
      end

      add_ons
    end

    def parse_package(rate)
      weight = rate.get_text('WeightOz').to_s.to_f

      dimensions = %w(Length Width Height).map do |dim|
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

    def parse_create_indicium_response(indicium, response_options)
      parse_authenticator(indicium)

      response_options[:shipping_id]       = indicium.get_text('IntegratorTxID').to_s
      response_options[:tracking_number]   = indicium.get_text('TrackingNumber').to_s if indicium.get_text('TrackingNumber')
      response_options[:stamps_tx_id]      = indicium.get_text('StampsTxID').to_s
      response_options[:label_url]         = indicium.get_text('URL').to_s if indicium.get_text('URL')
      response_options[:available_postage] = indicium.get_text('PostageBalance/AvailablePostage').to_s
      response_options[:control_total]     = indicium.get_text('PostageBalance/ControlTotal').to_s
      response_options[:image_data]        = Base64.decode64(indicium.get_text('ImageData/base64Binary').to_s) if indicium.get_text('ImageData/base64Binary')
      response_options[:rate]              = parse_rate(indicium.elements['Rate'])

      StampsShippingResponse.new(true, '', {}, response_options)
    end

    def parse_track_shipment_response(track_shipment, response_options)
      parse_authenticator(track_shipment)

      response_options[:carrier] = @@name

      shipment_events = track_shipment.get_elements('TrackingEvents/TrackingEvent').map do |event|
        unless response_options[:status]
          response_options[:status_code] = event.get_text('TrackingEventType').to_s
          response_options[:status] = response_options[:status_code].underscore.to_sym
        end

        response_options[:delivery_signature] = event.get_text('SignedBy').to_s if event.get_text('SignedBy')

        description = event.get_text('Event').to_s

        timestamp = event.get_text('Timestamp').to_s
        date, time = timestamp.split('T')
        year, month, day = date.split('-')
        hour, minute, second = time.split(':')
        zoneless_time = Time.utc(year, month, day, hour, minute, second)

        location = Location.new(
          city:    event.get_text('City').to_s,
          state:   event.get_text('State').to_s,
          zip:     event.get_text('Zip').to_s,
          country: event.get_text('Country').to_s
        )

        ShipmentEvent.new(description, zoneless_time, location)
      end

      response_options[:shipment_events] = shipment_events.sort_by(&:time)
      response_options[:delivered] = response_options[:status] == :delivered

      TrackingResponse.new(true, '', {}, response_options)
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

  class StampsPurchasePostageResponse < Response
    attr_reader :purchase_status, :transaction_id, :available_postage, :control_total, :rejection_reason

    def initialize(success, message, params = {}, options = {})
      super
      @purchase_status   = options[:purchase_status]
      @transaction_id    = options[:transaction_id]
      @available_postage = options[:available_postage]
      @control_total     = options[:control_total]
      @rejection_reason  = options[:rejection_reason]
    end
  end

  class StampsCleanseAddressResponse < Response
    attr_reader :address, :address_match, :city_state_zip_ok, :candidate_addresses, :cleanse_hash, :override_hash

    alias_method :address_match?, :address_match
    alias_method :city_state_zip_ok?, :city_state_zip_ok

    def initialize(success, message, params = {}, options = {})
      super
      @address             = options[:address]
      @address_match       = options[:address_match]
      @city_state_zip_ok   = options[:city_state_zip_ok]
      @candidate_addresses = options[:candidate_addresses]
      @cleanse_hash        = options[:cleanse_hash]
      @override_hash       = options[:override_hash]
    end
  end

  class StampsRateEstimate < RateEstimate
    attr_reader :add_ons

    def initialize(origin, destination, carrier, service_name, options = {})
      super
      @add_ons = options[:add_ons]
    end

    def available_add_ons
      add_ons.keys
    end
  end

  class StampsShippingResponse < ShippingResponse
    include ActiveUtils::PostsData

    attr_reader :rate, :stamps_tx_id, :label_url, :available_postage, :control_total

    def initialize(success, message, params = {}, options = {})
      super
      @rate              = options[:rate]
      @stamps_tx_id      = options[:stamps_tx_id]
      @label_url         = options[:label_url]
      @image_data        = options[:image_data]
      @available_postage = options[:available_postage]
      @control_total     = options[:control_total]
    end

    def image
      @image_data ||= ssl_get(label_url)
    end
  end
end
