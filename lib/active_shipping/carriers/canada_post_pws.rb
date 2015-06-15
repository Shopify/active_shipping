module ActiveShipping
  class CanadaPostPWS < Carrier
    @@name = "Canada Post PWS"

    SHIPPING_SERVICES = {
      "DOM.RP"        => "Regular Parcel",
      "DOM.EP"        => "Expedited Parcel",
      "DOM.XP"        => "Xpresspost",
      "DOM.XP.CERT"   => "Xpresspost Certified",
      "DOM.PC"        => "Priority",
      "DOM.LIB"       => "Library Books",

      "USA.EP"        => "Expedited Parcel USA",
      "USA.PW.ENV"    => "Priority Worldwide Envelope USA",
      "USA.PW.PAK"    => "Priority Worldwide pak USA",
      "USA.PW.PARCEL" => "Priority Worldwide Parcel USA",
      "USA.SP.AIR"    => "Small Packet USA Air",
      "USA.SP.SURF"   => "Small Packet USA Surface",
      "USA.XP"        => "Xpresspost USA",

      "INT.XP"        => "Xpresspost International",
      "INT.IP.AIR"    => "International Parcel Air",
      "INT.IP.SURF"   => "International Parcel Surface",
      "INT.PW.ENV"    => "Priority Worldwide Envelope Int'l",
      "INT.PW.PAK"    => "Priority Worldwide pak Int'l",
      "INT.PW.PARCEL" => "Priority Worldwide parcel Int'l",
      "INT.SP.AIR"    => "Small Packet International Air",
      "INT.SP.SURF"   => "Small Packet International Surface"
    }

    ENDPOINT = "https://soa-gw.canadapost.ca/"    # production

    SHIPMENT_MIMETYPE = "application/vnd.cpc.ncshipment+xml"
    RATE_MIMETYPE = "application/vnd.cpc.ship.rate+xml"
    TRACK_MIMETYPE = "application/vnd.cpc.track+xml"
    REGISTER_MIMETYPE = "application/vnd.cpc.registration+xml"

    LANGUAGE = {
      'en' => 'en-CA',
      'fr' => 'fr-CA'
    }

    SHIPPING_OPTIONS = [:d2po, :d2po_office_id, :cov, :cov_amount, :cod, :cod_amount, :cod_includes_shipping,
                        :cod_method_of_payment, :so, :dc, :dns, :pa18, :pa19, :hfp, :lad,
                        :rase, :rts, :aban]

    RATES_OPTIONS = [:cov, :cov_amount, :cod, :so, :dc, :dns, :pa18, :pa19, :hfp, :lad]

    MAX_WEIGHT = 30 # kg

    attr_accessor :language, :endpoint, :logger, :platform_id, :customer_number

    def initialize(options = {})
      @language = LANGUAGE[options[:language]] || LANGUAGE['en']
      @endpoint = options[:endpoint] || ENDPOINT
      @platform_id = options[:platform_id]
      @customer_number = options[:customer_number]
      super(options)
    end

    def requirements
      [:api_key, :secret]
    end

    def find_rates(origin, destination, line_items = [], options = {}, package = nil, services = [])
      url = endpoint + "rs/ship/price"
      request  = build_rates_request(origin, destination, line_items, options, package, services)
      response = ssl_post(url, request, headers(options, RATE_MIMETYPE, RATE_MIMETYPE))
      parse_rates_response(response, origin, destination)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSRateResponse)
    end

    def find_tracking_info(pin, options = {})
      response = ssl_get(tracking_url(pin), headers(options, TRACK_MIMETYPE))
      parse_tracking_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      if e.response
        error_response(e.response.body, CPPWSTrackingResponse)
      else
        CPPWSTrackingResponse.new(false, e.message, {}, :carrier => @@name)
      end
    rescue InvalidPinFormatError
      CPPWSTrackingResponse.new(false, "Invalid Pin Format", {}, :carrier => @@name)
    end

    # line_items should be a list of PackageItem's
    def create_shipment(origin, destination, package, line_items = [], options = {})
      request_body = build_shipment_request(origin, destination, package, line_items, options)
      response = ssl_post(create_shipment_url(options), request_body, headers(options, SHIPMENT_MIMETYPE, SHIPMENT_MIMETYPE))
      parse_shipment_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSShippingResponse)
    rescue MissingCustomerNumberError
      CPPWSShippingResponse.new(false, "Missing Customer Number", {}, :carrier => @@name)
    end

    def retrieve_shipment(shipping_id, options = {})
      response = ssl_post(shipment_url(shipping_id, options), nil, headers(options, SHIPMENT_MIMETYPE, SHIPMENT_MIMETYPE))
      parse_shipment_response(response)
    end

    def find_shipment_receipt(shipping_id, options = {})
      response = ssl_get(shipment_receipt_url(shipping_id, options), headers(options, SHIPMENT_MIMETYPE, SHIPMENT_MIMETYPE))
      parse_shipment_receipt_response(response)
    end

    def retrieve_shipping_label(shipping_response, options = {})
      raise MissingShippingNumberError unless shipping_response && shipping_response.shipping_id
      ssl_get(shipping_response.label_url, headers(options, "application/pdf"))
    end

    def register_merchant(options = {})
      url = endpoint + "ot/token"
      response = ssl_post(url, nil, headers({}, REGISTER_MIMETYPE, REGISTER_MIMETYPE).merge("Content-Length" => "0"))
      parse_register_token_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSRegisterResponse)
    end

    def retrieve_merchant_details(options = {})
      raise MissingTokenIdError unless token_id = options[:token_id]
      url = endpoint + "ot/token/#{token_id}"
      response = ssl_get(url, headers({}, REGISTER_MIMETYPE, REGISTER_MIMETYPE))
      parse_merchant_details_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSMerchantDetailsResponse)
    rescue Exception => e
      raise ResponseError.new(e.message)
    end

    def find_services(country = nil, options = {})
      response = ssl_get(services_url(country), headers(options, RATE_MIMETYPE))
      parse_services_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSRateResponse)
    end

    def find_service_options(service_code, country, options = {})
      response = ssl_get(services_url(country, service_code), headers(options, RATE_MIMETYPE))
      parse_service_options_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSRateResponse)
    end

    def find_option_details(option_code, options = {})
      url = endpoint + "rs/ship/option/#{option_code}"
      response = ssl_get(url, headers(options, RATE_MIMETYPE))
      parse_option_response(response)
    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      error_response(e.response.body, CPPWSRateResponse)
    end

    def maximum_weight
      Mass.new(MAX_WEIGHT, :kilograms)
    end

    def maximum_address_field_length
      # https://www.canadapost.ca/cpo/mc/business/productsservices/developers/services/shippingmanifest/createshipment.jsf
      44
    end

    # service discovery

    def parse_services_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      service_nodes = doc.xpath('services/service')
      service_nodes.inject({}) do |result, node|
        service_code = node.at("service-code").text
        service_name = node.at("service-name").text
        service_link = node.at("link").attributes['href'].value
        service_link_media_type = node.at("link").attributes['media-type'].value
        result[service_code] = {
          :name => service_name,
          :link => service_link,
          :link_media_type => service_link_media_type
        }
        result
      end
    end

    def parse_service_options_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!

      service_code = doc.root.at("service-code").text
      service_name = doc.root.at("service-name").text

      option_nodes = doc.root.xpath('options/option')
      options = option_nodes.map do |node|
        option = {
          :code => node.at("option-code").text,
          :name => node.at("option-name").text,
          :required => node.at("mandatory").text != "false",
          :qualifier_required => node.at("qualifier-required").text != "false",
        }
        option[:qualifier_max] = node.at("qualifier-max").text.to_i if node.at("qualifier-max")
        option
      end

      restrictions_node = doc.root.at('restrictions')
      dimensions_node = restrictions_node.at('dimensional-restrictions')
      restrictions = {
        :min_weight => restrictions_node.at("weight-restriction").attributes['min'].value.to_i,
        :max_weight => restrictions_node.at("weight-restriction").attributes['max'].value.to_i,
        :min_length => dimensions_node.at("length").attributes['min'].value.to_f,
        :max_length => dimensions_node.at("length").attributes['max'].value.to_f,
        :min_height => dimensions_node.at("height").attributes['min'].value.to_f,
        :max_height => dimensions_node.at("height").attributes['max'].value.to_f,
        :min_width => dimensions_node.at("width").attributes['min'].value.to_f,
        :max_width => dimensions_node.at("width").attributes['max'].value.to_f
      }

      {
        :service_code => service_code,
        :service_name => service_name,
        :options => options,
        :restrictions => restrictions
      }
    end

    def parse_option_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!

      conflicts = doc.root.xpath('conflicting-options/option-code').map(&:text)
      prereqs = doc.root.xpath('prerequisite-options/option-code').map(&:text)
      option = {
        :code => doc.root.at('option-code').text,
        :name => doc.root.at('option-name').text,
        :class => doc.root.at('option-class').text,
        :prints_on_label => doc.root.at('prints-on-label').text != "false",
        :qualifier_required => doc.root.at('qualifier-required').text != "false",
      }
      option[:conflicting_options] = conflicts if conflicts
      option[:prerequisite_options] = prereqs if prereqs

      option[:qualifier_max] = doc.root.at("qualifier-max").text.to_i if doc.root.at("qualifier-max")
      option
    end

    # rating

    def build_rates_request(origin, destination, line_items = [], options = {}, package = nil, services = [])
      line_items = Array(line_items)

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.public_send('mailing-scenario', :xmlns => "http://www.canadapost.ca/ws/ship/rate") do
          customer_number_node(xml, options)
          contract_id_node(xml, options)
          quote_type_node(xml, options)
          expected_mailing_date_node(xml, shipping_date(options)) if options[:shipping_date]
          shipping_options_node(xml, RATES_OPTIONS, options)
          parcel_node(xml, line_items, package)
          origin_node(xml, origin)
          destination_node(xml, destination)
          services_node(xml, services) unless services.blank?
        end
      end
      builder.to_xml
    end

    def parse_rates_response(response, origin, destination)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      raise ActiveShipping::ResponseError, "No Quotes" unless doc.at('price-quotes')

      rates = doc.root.xpath('price-quote').map do |node|
        service_name  = node.at("service-name").text
        service_code  = node.at("service-code").text
        total_price   = node.at('price-details/due').text
        expected_date = expected_date_from_node(node)
        options = {
          :service_code   => service_code,
          :total_price    => total_price,
          :currency       => 'CAD',
          :delivery_range => [expected_date, expected_date]
        }
        RateEstimate.new(origin, destination, @@name, service_name, options)
      end
      CPPWSRateResponse.new(true, "", {}, :rates => rates)
    end

    # tracking

    def parse_tracking_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      raise ActiveShipping::ResponseError, "No Tracking" unless doc.at('tracking-detail')

      events = doc.root.xpath('significant-events/occurrence')

      shipment_events  = build_tracking_events(events)
      change_date      = doc.root.at('changed-expected-date').text
      expected_date    = doc.root.at('expected-delivery-date').text
      dest_postal_code = doc.root.at('destination-postal-id').text
      destination      = Location.new(:postal_code => dest_postal_code)
      origin           = Location.new(origin_hash_for(doc.root))
      options = {
        :carrier                 => @@name,
        :service_name            => doc.root.at('service-name').text,
        :expected_date           => expected_date.blank? ? nil : Date.parse(expected_date),
        :changed_date            => change_date.blank? ? nil : Date.parse(change_date),
        :change_reason           => doc.root.at('changed-expected-delivery-reason').text.strip,
        :destination_postal_code => doc.root.at('destination-postal-id').text,
        :shipment_events         => shipment_events,
        :tracking_number         => doc.root.at('pin').text,
        :origin                  => origin,
        :destination             => destination,
        :customer_number         => doc.root.at('mailed-by-customer-number').text
      }

      CPPWSTrackingResponse.new(true, "", {}, options)
    end

    def build_tracking_events(events)
      events.map do |event|
        date      = event.at('event-date').text
        time      = event.at('event-time').text
        zone      = event.at('event-time-zone').text
        timestamp = DateTime.parse("#{date} #{time} #{zone}")
        time      = Time.utc(timestamp.utc.year, timestamp.utc.month, timestamp.utc.day, timestamp.utc.hour, timestamp.utc.min, timestamp.utc.sec)
        message   = event.at('event-description').text
        location  = [event.at('event-retail-name'), event.at('event-site'), event.at('event-province')].
                      reject { |e| e.nil? || e.text.empty? }.join(", ")
        name      = event.at('event-identifier').text
        ShipmentEvent.new(name, time, location, message)
      end
    end

    # shipping

    # options
    # :service => 'DOM.EP'
    # :notification_email
    # :packing_instructions
    # :show_postage_rate
    # :cod, :cod_amount, :insurance, :insurance_amount, :signature_required, :pa18, :pa19, :hfp, :dns, :lad
    #
    def build_shipment_request(origin, destination, package, line_items = [], options = {})
      origin = sanitize_location(origin)
      destination = sanitize_location(destination)

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.public_send('non-contract-shipment', :xmlns => "http://www.canadapost.ca/ws/ncshipment") do
          xml.public_send('delivery-spec') do
            shipment_service_code_node(xml, options)
            shipment_sender_node(xml, origin, options)
            shipment_destination_node(xml, destination, options)
            shipment_options_node(xml, options)
            shipment_parcel_node(xml, package)
            shipment_notification_node(xml, options)
            shipment_preferences_node(xml, options)
            references_node(xml, options)             # optional > user defined custom notes
            shipment_customs_node(xml, destination, line_items, options)
            # COD Remittance defaults to sender
          end
        end
      end
      builder.to_xml
    end

    def shipment_service_code_node(xml, options)
      xml.public_send('service-code', options[:service])
    end

    def shipment_sender_node(xml, location, options)
      xml.public_send('sender') do
        xml.public_send('name', location.name)
        xml.public_send('company', location.company) if location.company.present?
        xml.public_send('contact-phone', location.phone)
        xml.public_send('address-details') do
          xml.public_send('address-line-1', location.address1)
          xml.public_send('address-line-2', location.address2_and_3) unless location.address2_and_3.blank?
          xml.public_send('city', location.city)
          xml.public_send('prov-state', location.province)
          # xml.public_send('country-code', location.country_code)
          xml.public_send('postal-zip-code', location.postal_code)
        end
      end
    end

    def shipment_destination_node(xml, location, options)
      xml.public_send('destination') do
        xml.public_send('name', location.name)
        xml.public_send('company', location.company) if location.company.present?
        xml.public_send('client-voice-number', location.phone)
        xml.public_send('address-details') do
          xml.public_send('address-line-1', location.address1)
          xml.public_send('address-line-2', location.address2_and_3) unless location.address2_and_3.blank?
          xml.public_send('city', location.city)
          xml.public_send('prov-state', location.province) unless location.province.blank?
          xml.public_send('country-code', location.country_code)
          xml.public_send('postal-zip-code', location.postal_code)
        end
      end
    end

    def shipment_options_node(xml, options)
      shipping_options_node(xml, SHIPPING_OPTIONS, options)
    end

    def shipment_notification_node(xml, options)
      return unless options[:notification_email]
      xml.public_send('notification') do
        xml.public_send('email', options[:notification_email])
        xml.public_send('on-shipment', true)
        xml.public_send('on-exception', true)
        xml.public_send('on-delivery', true)
      end
    end

    def shipment_preferences_node(xml, options)
      xml.public_send('preferences') do
        xml.public_send('show-packing-instructions', options[:packing_instructions] || true)
        xml.public_send('show-postage-rate', options[:show_postage_rate] || false)
        xml.public_send('show-insured-value', true)
      end
    end

    def references_node(xml, options)
      # custom values
      # xml.public_send('references') do
      # end
    end

    def shipment_customs_node(xml, destination, line_items, options)
      return unless destination.country_code != 'CA'

      xml.public_send('customs') do
        currency = options[:currency] || "CAD"
        xml.public_send('currency', currency)
        xml.public_send('conversion-from-cad', options[:conversion_from_cad].to_s) if currency != 'CAD' && options[:conversion_from_cad]
        xml.public_send('reason-for-export', 'SOG') # SOG - Sale of Goods
        xml.public_send('other-reason', options[:customs_other_reason]) if options[:customs_reason_for_export] && options[:customs_other_reason]
        xml.public_send('additional-customs-info', options[:customs_addition_info]) if options[:customs_addition_info]
        xml.public_send('sku-list') do
          line_items.each do |line_item|
            kg = '%#2.3f' % [sanitize_weight_kg(line_item.kg)]
            xml.public_send('item') do
              xml.public_send('hs-tariff-code', line_item.hs_code) if line_item.hs_code && !line_item.hs_code.empty?
              xml.public_send('sku', line_item.sku) if line_item.sku && !line_item.sku.empty?
              xml.public_send('customs-description', line_item.name.slice(0, 44))
              xml.public_send('unit-weight', kg)
              xml.public_send('customs-value-per-unit', '%.2f' % sanitize_price_from_cents(line_item.value))
              xml.public_send('customs-number-of-units', line_item.quantity)
              xml.public_send('country-of-origin', line_item.options[:country_of_origin]) if line_item.options && line_item.options[:country_of_origin] && !line_item.options[:country_of_origin].empty?
              xml.public_send('province-of-origin', line_item.options[:province_of_origin]) if line_item.options && line_item.options[:province_of_origin] && !line_item.options[:province_of_origin].empty?
            end
          end
        end

      end
    end

    def shipment_parcel_node(xml, package, options = {})
      weight = sanitize_weight_kg(package.kilograms.to_f)
      xml.public_send('parcel-characteristics') do
        xml.public_send('weight', "%#2.3f" % weight)
        pkg_dim = package.cm
        if pkg_dim && !pkg_dim.select { |x| x != 0 }.empty?
          xml.public_send('dimensions') do
            xml.public_send('length', '%.1f' % ((pkg_dim[2] * 10).round / 10.0)) if pkg_dim.size >= 3
            xml.public_send('width', '%.1f' % ((pkg_dim[1] * 10).round / 10.0)) if pkg_dim.size >= 2
            xml.public_send('height', '%.1f' % ((pkg_dim[0] * 10).round / 10.0)) if pkg_dim.size >= 1
          end
          xml.public_send('document', false)
        else
          xml.public_send('document', true)
        end

        xml.public_send('mailing-tube', package.tube?)
        xml.public_send('unpackaged', package.unpackaged?)
      end
    end

    def parse_shipment_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      raise ActiveShipping::ResponseError, "No Shipping" unless doc.at('non-contract-shipment-info')
      options = {
        :shipping_id      => doc.root.at('shipment-id').text,
        :tracking_number  => doc.root.at('tracking-pin').text,
        :details_url      => doc.root.at_xpath("links/link[@rel='details']")['href'],
        :label_url        => doc.root.at_xpath("links/link[@rel='label']")['href'],
        :receipt_url      => doc.root.at_xpath("links/link[@rel='receipt']")['href'],
      }
      CPPWSShippingResponse.new(true, "", {}, options)
    end

    def parse_register_token_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      raise ActiveShipping::ResponseError, "No Registration Token" unless doc.at('token')
      options = {
        :token_id => doc.root.at('token-id').text
      }
      CPPWSRegisterResponse.new(true, "", {}, options)
    end

    def parse_merchant_details_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      raise "No Merchant Info" unless doc.at('merchant-info')
      raise "No Merchant Info" if doc.root.at('customer-number').blank?
      options = {
        :customer_number => doc.root.at('customer-number').text,
        :contract_number => doc.root.at('contract-number').text,
        :username => doc.root.at('merchant-username').text,
        :password => doc.root.at('merchant-password').text,
        :has_default_credit_card => doc.root.at('has-default-credit-card').text == 'true'
      }
      CPPWSMerchantDetailsResponse.new(true, "", {}, options)
    end

    def parse_shipment_receipt_response(response)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      root = doc.at('non-contract-shipment-receipt')
      cc_details_node = root.at('cc-receipt-details')
      service_standard_node = root.at('service-standard')
      receipt = {
        :final_shipping_point => root.at("final-shipping-point").text,
        :shipping_point_name => root.at("shipping-point-name").text,
        :service_code => root.at("service-code").text,
        :rated_weight => root.at("rated-weight").text.to_f,
        :base_amount => root.at("base-amount").text.to_f,
        :pre_tax_amount => root.at("pre-tax-amount").text.to_f,
        :gst_amount => root.at("gst-amount").text.to_f,
        :pst_amount => root.at("pst-amount").text.to_f,
        :hst_amount => root.at("hst-amount").text.to_f,
        :charge_amount => cc_details_node.at("charge-amount").text.to_f,
        :currency => cc_details_node.at("currency").text,
        :expected_transit_days => service_standard_node.at("expected-transit-time").text.to_i,
        :expected_delivery_date => service_standard_node.at("expected-delivery-date").text
      }
      option_nodes = root.xpath('priced-options/priced-option')

      receipt[:priced_options] = if option_nodes.length > 0
        option_nodes.inject({}) do |result, node|
          result[node.at("option-code").text] = node.at("option-price").text.to_f
          result
          end
      else
        {}
      end

      receipt
    end

    def error_response(response, response_klass)
      doc = Nokogiri.XML(response)
      doc.remove_namespaces!
      messages = doc.xpath('messages/message')
      message = messages.map { |m| m.at('description').text }.join(", ")
      code = messages.map { |m| m.at('code').text }.join(", ")
      response_klass.new(false, message, {}, :carrier => @@name, :code => code)
    end

    def log(msg)
      logger.debug(msg) if logger
    end

    private

    def tracking_url(pin)
      case pin.length
        when 12, 13, 16
          endpoint + "vis/track/pin/%s/detail" % pin
        when 15
          endpoint + "vis/track/dnc/%s/detail" % pin
        else
          raise InvalidPinFormatError
        end
    end

    def create_shipment_url(options)
      raise MissingCustomerNumberError unless customer_number = options[:customer_number]
      if @platform_id.present?
        endpoint + "rs/#{customer_number}-#{@platform_id}/ncshipment"
      else
        endpoint + "rs/#{customer_number}/ncshipment"
      end
    end

    def shipment_url(shipping_id, options = {})
      raise MissingCustomerNumberError unless customer_number = options[:customer_number]
      if @platform_id.present?
        endpoint + "rs/#{customer_number}-#{@platform_id}/ncshipment/#{shipping_id}"
      else
        endpoint + "rs/#{customer_number}/ncshipment/#{shipping_id}"
      end
    end

    def shipment_receipt_url(shipping_id, options = {})
      raise MissingCustomerNumberError unless customer_number = options[:customer_number]
      if @platform_id.present?
        endpoint + "rs/#{customer_number}-#{@platform_id}/ncshipment/#{shipping_id}/receipt"
      else
        endpoint + "rs/#{customer_number}/ncshipment/#{shipping_id}/receipt"
      end
    end

    def services_url(country = nil, service_code = nil)
      url = endpoint + "rs/ship/service"
      url += "/#{service_code}" if service_code
      url += "?country=#{country}" if country
      url
    end

    def customer_credentials_valid?(credentials)
      (credentials.keys & [:customer_api_key, :customer_secret]).any?
    end

    def encoded_authorization(customer_credentials = {})
      if customer_credentials_valid?(customer_credentials)
        "Basic %s" % Base64.encode64("#{customer_credentials[:customer_api_key]}:#{customer_credentials[:customer_secret]}")
      else
        "Basic %s" % Base64.encode64("#{@options[:api_key]}:#{@options[:secret]}")
      end
    end

    def headers(customer_credentials, accept = nil, content_type = nil)
      headers = {
        'Authorization'   => encoded_authorization(customer_credentials),
        'Accept-Language' => language
      }
      headers['Accept'] = accept if accept
      headers['Content-Type'] = content_type if content_type
      headers['Platform-ID'] = platform_id if platform_id && customer_credentials_valid?(customer_credentials)
      headers
    end

    def customer_number_node(xml, options)
      xml.public_send("customer-number", options[:customer_number] || customer_number)
    end

    def contract_id_node(xml, options)
      xml.public_send("contract-id", options[:contract_id]) if options[:contract_id]
    end

    def quote_type_node(xml, options)
      xml.public_send("quote-type", 'commercial')
    end

    def expected_mailing_date_node(xml, date_as_string)
      xml.public_send("expected-mailing-date", date_as_string)
    end

    def parcel_node(xml, line_items, package = nil, options = {})
      weight = sanitize_weight_kg(package && !package.kilograms.zero? ? package.kilograms.to_f : line_items.sum(&:kilograms).to_f)
      xml.public_send('parcel-characteristics') do
        xml.public_send('weight', "%#2.3f" % weight)
        if package
          pkg_dim = package.cm
          if pkg_dim && !pkg_dim.select { |x| x != 0 }.empty?
            xml.public_send('dimensions') do
              xml.public_send('length', '%.1f' % ((pkg_dim[2] * 10).round / 10.0)) if pkg_dim.size >= 3
              xml.public_send('width', '%.1f' % ((pkg_dim[1] * 10).round / 10.0)) if pkg_dim.size >= 2
              xml.public_send('height', '%.1f' % ((pkg_dim[0] * 10).round / 10.0)) if pkg_dim.size >= 1
            end
          end
        end
        xml.public_send('mailing-tube', line_items.any?(&:tube?))
        xml.public_send('oversized', true) if line_items.any?(&:oversized?)
        xml.public_send('unpackaged', line_items.any?(&:unpackaged?))
      end
    end

    def origin_node(xml, location)
      origin = sanitize_location(location)
      xml.public_send("origin-postal-code", origin.zip)
    end

    def destination_node(xml, location)
      destination = sanitize_location(location)
      case destination.country_code
        when 'CA'
          xml.public_send('destination') do
            xml.public_send('domestic') do
              xml.public_send('postal-code', destination.postal_code)
            end
          end

        when 'US'
          xml.public_send('destination') do
            xml.public_send('united-states') do
              xml.public_send('zip-code', destination.postal_code)
            end
          end

        else
          xml.public_send('destination') do
            xml.public_send('international') do
              xml.public_send('country-code', destination.country_code)
            end
          end
      end
    end

    def services_node(xml, services)
      xml.public_send('services') do
        services.each { |code| xml.public_send('service-code', code) }
      end
    end

    def shipping_options_node(xml, available_options, options = {})
      return if (options.symbolize_keys.keys & available_options).empty?
      xml.public_send('options') do

        if options[:cod] && options[:cod_amount]
          xml.public_send('option') do
            xml.public_send('option-code', 'COD')
            xml.public_send('option-amount', options[:cod_amount])
            xml.public_send('option-qualifier-1', options[:cod_includes_shipping]) unless options[:cod_includes_shipping].blank?
            xml.public_send('option-qualifier-2', options[:cod_method_of_payment]) unless options[:cod_method_of_payment].blank?
          end
        end

        if options[:cov]
          xml.public_send('option') do
            xml.public_send('option-code', 'COV')
            xml.public_send('option-amount', options[:cov_amount]) unless options[:cov_amount].blank?
          end
        end

        if options[:d2po]
          xml.public_send('option') do
            xml.public_send('option-code', 'D2PO')
            xml.public_send('option-qualifier-2'. options[:d2po_office_id]) unless options[:d2po_office_id].blank?
          end
        end

        [:so, :dc, :pa18, :pa19, :hfp, :dns, :lad, :rase, :rts, :aban].each do |code|
          if options[code]
            xml.public_send('option') do
              xml.public_send('option-code', code.to_s.upcase)
            end
          end
        end
      end
    end

    def expected_date_from_node(node)
      if service = node.at('service-standard/expected-delivery-date')
        expected_date = service.text
      else
        expected_date = nil
      end
      expected_date
    end

    def shipping_date(options)
      DateTime.strptime((options[:shipping_date] || Time.now).to_s, "%Y-%m-%d")
    end

    def sanitize_location(location)
      location_hash = location.is_a?(Location) ? location.to_hash : location
      location_hash = sanitize_zip(location_hash)
      Location.new(location_hash)
    end

    def sanitize_zip(hash)
      [:postal_code, :zip].each do |attr|
        hash[attr].gsub!(/\s+/, '') if hash[attr]
      end
      hash
    end

    def sanitize_weight_kg(kg)
      kg == 0 ? 0.001 : kg
    end

    def sanitize_price_from_cents(value)
      value == 0 ? 0.01 : value.round / 100.0
    end

    def origin_hash_for(root)
      occurrences = root.xpath('significant-events/occurrence')
      earliest = occurrences.sort_by { |occurrence| time_of_occurrence(occurrence) }.first

      {
        city: earliest.at('event-site').text,
        province: earliest.at('event-province').text,
        address_1: earliest.at('event-retail-location-id').text,
        country: 'Canada'
      }
    end

    def time_of_occurrence(occurrence)
      time = occurrence.at('event-time').text
      date = occurrence.at('event-date').text
      time_zone = occurrence.at('event-time-zone').text
      DateTime.parse "#{date} #{time} #{time_zone}"
    end
  end

  module CPPWSErrorResponse
    attr_accessor :error_code
    def handle_error(message, options)
      @error_code = options[:code]
    end
  end

  class CPPWSRateResponse < RateResponse
    include CPPWSErrorResponse

    def initialize(success, message, params = {}, options = {})
      handle_error(message, options)
      super
    end
  end

  class CPPWSTrackingResponse < TrackingResponse
    DELIVERED_EVENT_CODES = %w(1496 1498 1499 1409 1410 1411 1412 1413 1414 1415 1416 1417 1418 1419 1420 1421 1422 1423 1424 1425 1426 1427 1428 1429 1430 1431 1432 1433 1434 1435 1436 1437 1438)
    include CPPWSErrorResponse

    attr_reader :service_name, :expected_date, :changed_date, :change_reason, :customer_number

    def initialize(success, message, params = {}, options = {})
      handle_error(message, options)
      super
      @service_name    = options[:service_name]
      @expected_date   = options[:expected_date]
      @changed_date    = options[:changed_date]
      @change_reason   = options[:change_reason]
      @customer_number = options[:customer_number]
    end

    def delivered?
      !delivered_event.nil?
    end

    def actual_delivery_time
      delivered_event.time if delivered?
    end

    private

    def delivered_event
      @delivered_event ||= @shipment_events.detect { |event| DELIVERED_EVENT_CODES.include? event.name }
    end
  end

  class CPPWSShippingResponse < ShippingResponse
    include CPPWSErrorResponse
    attr_reader :label_url, :details_url, :receipt_url
    def initialize(success, message, params = {}, options = {})
      handle_error(message, options)
      super
      @label_url      = options[:label_url]
      @details_url    = options[:details_url]
      @receipt_url    = options[:receipt_url]
    end
  end

  class CPPWSRegisterResponse < Response
    include CPPWSErrorResponse
    attr_reader :token_id
    def initialize(success, message, params = {}, options = {})
      handle_error(message, options)
      super
      @token_id = options[:token_id]
    end

    def redirect_url(customer_id, return_url)
      "http://www.canadapost.ca/cpotools/apps/drc/merchant?return-url=#{CGI.escape(return_url)}&token-id=#{token_id}&platform-id=#{customer_id}"
    end
  end

  class CPPWSMerchantDetailsResponse < Response
    include CPPWSErrorResponse
    attr_reader :customer_number, :contract_number, :username, :password, :has_default_credit_card
    def initialize(success, message, params = {}, options = {})
      handle_error(message, options)
      super
      @customer_number = options[:customer_number]
      @contract_number = options[:contract_number]
      @username = options[:username]
      @password = options[:password]
      @has_default_credit_card = options[:has_default_credit_card]
    end
  end

  class InvalidPinFormatError < StandardError; end
  class MissingCustomerNumberError < StandardError; end
  class MissingShippingNumberError < StandardError; end
  class MissingTokenIdError < StandardError; end
end
