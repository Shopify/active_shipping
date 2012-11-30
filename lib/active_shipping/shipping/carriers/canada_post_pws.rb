require 'cgi'

module ActiveMerchant
  module Shipping
          
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

      attr_accessor :language, :endpoint, :logger, :platform_id

      def initialize(options = {})
        @language = LANGUAGE[options[:language]] || LANGUAGE['en']
        @endpoint = options[:endpoint] || ENDPOINT
        @platform_id = options[:platform_id]
        super(options)
      end
      
      def requirements
        [:api_key, :secret]
      end

      def find_services(country = nil, options = {})
        url = endpoint + "rs/ship/service"
        url += "?country=#{country}" if country
        response = ssl_get(url, headers(options, RATE_MIMETYPE))
        parse_services_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSRateResponse)
      end

      def find_service_options(service_code, country, options = {})
        url = endpoint + "rs/ship/service/#{service_code}"
        url += "?country=#{country}" if country
        response = ssl_get(url, headers(options, RATE_MIMETYPE))
        parse_service_options_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSRateResponse)
      end

      def find_option_details(option_code, options = {})
        url = endpoint + "rs/ship/option/#{option_code}"
        response = ssl_get(url, headers(options, RATE_MIMETYPE))
        parse_option_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSRateResponse)
      end
      
      def find_rates(origin, destination, line_items = [], options = {}, package = nil)
        url = endpoint + "rs/ship/price"
        request  = build_rates_request(origin, destination, line_items, options, package)
        response = ssl_post(url, request, headers(options, RATE_MIMETYPE, RATE_MIMETYPE))
        parse_rates_response(response, origin, destination)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSRateResponse)
      end
      
      def find_tracking_info(pin, options = {})
        url = case pin.length
          when 12,13,16
            endpoint + "vis/track/pin/%s/detail" % pin
          when 15
            endpoint + "vis/track/dnc/%s/detail" % pin
          else
            raise InvalidPinFormatError
          end

        response = ssl_get(url, headers(options, TRACK_MIMETYPE))
        parse_tracking_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSTrackingResponse)
      rescue InvalidPinFormatError => e
        CPPWSTrackingResponse.new(false, "Invalid Pin Format", {}, {:carrier => @@name})
      end
      
      # line_items should be a list of PackageItem's
      def create_shipment(origin, destination, package, line_items = [], options = {})
        raise MissingCustomerNumberError unless customer_number = options[:customer_number]
        if @platform_id.present?
          url = endpoint + "rs/#{customer_number}-#{@platform_id}/ncshipment"
        else
          url = endpoint + "rs/#{customer_number}/ncshipment"
        end

        request_body = build_shipment_request(origin, destination, package, line_items, options)

        response = ssl_post(url, request_body, headers(options, SHIPMENT_MIMETYPE, SHIPMENT_MIMETYPE))
        parse_shipment_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSShippingResponse)
      rescue MissingCustomerNumberError => e
        CPPWSShippingResponse.new(false, "Missing Customer Number", {}, {:carrier => @@name})
      end

      def retrieve_shipment(shipping_id, options = {})
        raise MissingCustomerNumberError unless customer_number = options[:customer_number]
        if @platform_id.present?
          url = endpoint + "rs/#{customer_number}-#{@platform_id}/ncshipment/#{shipping_id}"
        else
          url = endpoint + "rs/#{customer_number}/ncshipment/#{shipping_id}"
        end
        response = ssl_post(url, nil, headers(options, SHIPMENT_MIMETYPE, SHIPMENT_MIMETYPE))
        shipping_response = parse_shipment_response(response)
      end

      def find_shipment_receipt(shipping_id, options = {})
        raise MissingCustomerNumberError unless customer_number = options[:customer_number]
        if @platform_id.present?
          url = endpoint + "rs/#{customer_number}-#{@platform_id}/ncshipment/#{shipping_id}/receipt"
        else
          url = endpoint + "rs/#{customer_number}/ncshipment/#{shipping_id}/receipt"
        end
        response = ssl_get(url, headers(options, SHIPMENT_MIMETYPE, SHIPMENT_MIMETYPE))
        shipping_response = parse_shipment_receipt_response(response)
      end
      
      def retrieve_shipping_label(shipping_response, options = {})
        raise MissingShippingNumberError unless shipping_response && shipping_response.shipping_id
        ssl_get(shipping_response.label_url, headers(options, "application/pdf"))
      end

      def register_merchant(options = {})
        url = endpoint + "ot/token"
        response = ssl_post(url, nil, headers({}, REGISTER_MIMETYPE, REGISTER_MIMETYPE).merge({"Content-Length" => "0"}))
        parse_register_token_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSRegisterResponse)
      end

      def retrieve_merchant_details(options = {})
        raise MissingTokenIdError unless token_id = options[:token_id]
        url = endpoint + "ot/token/#{token_id}"
        response = ssl_get(url, headers({}, REGISTER_MIMETYPE, REGISTER_MIMETYPE))
        parse_merchant_details_response(response)
      rescue ActiveMerchant::ResponseError, ActiveMerchant::Shipping::ResponseError => e
        error_response(e.response.body, CPPWSMerchantDetailsResponse)
      rescue Exception => e
        raise ResponseError.new(e.message)
      end
      
      def maximum_weight
        Mass.new(MAX_WEIGHT, :kilograms)
      end

      # service discovery

      def parse_services_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        service_nodes = doc.elements['services'].elements.collect('service') {|node| node }
        services = service_nodes.inject({}) do |result, node|
          service_code = node.get_text("service-code").to_s
          service_name = node.get_text("service-name").to_s
          service_link = node.elements["link"].attributes['href']
          service_link_media_type = node.elements["link"].attributes['media-type']
          result[service_code] = {
            :name => service_name,
            :link => service_link,
            :link_media_type => service_link_media_type
          }
          result
        end
        services
      end

      def parse_service_options_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        service_node = doc.elements['service']
        service_code = service_node.get_text("service-code").to_s
        service_name = service_node.get_text("service-name").to_s
        option_nodes = service_node.elements['options'].elements.collect('option') {|node| node}
        options = option_nodes.inject([]) do |result, node|
          option = {
            :code => node.get_text("option-code").to_s,
            :name => node.get_text("option-name").to_s,
            :required => node.get_text("mandatory").to_s == "false" ? false : true,
            :qualifier_required => node.get_text("qualifier-required").to_s == "false" ? false : true
          }
          option[:qualifier_max] = node.get_text("qualifier-max").to_s.to_i if node.get_text("qualifier-max")
          result << option
          result
        end
        restrictions_node = service_node.elements['restrictions']
        dimensions_node = restrictions_node.elements['dimensional-restrictions']
        restrictions = {
          :min_weight => restrictions_node.elements["weight-restriction"].attributes['min'].to_i,
          :max_weight => restrictions_node.elements["weight-restriction"].attributes['max'].to_i,
          :min_length => dimensions_node.elements["length"].attributes['min'].to_f,
          :max_length => dimensions_node.elements["length"].attributes['max'].to_f,
          :min_height => dimensions_node.elements["height"].attributes['min'].to_f,
          :max_height => dimensions_node.elements["height"].attributes['max'].to_f,
          :min_width => dimensions_node.elements["width"].attributes['min'].to_f,
          :max_width => dimensions_node.elements["width"].attributes['max'].to_f,
        }

        {
          :service_code => service_code,
          :service_name => service_name,
          :options => options,
          :restrictions => restrictions
        }
      end

      def parse_option_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        option_node = doc.elements['option']
        conflicts = option_node.elements['conflicting-options'].elements.collect('option-code') {|node| node.get_text.to_s} unless option_node.elements['conflicting-options'].blank?
        prereqs = option_node.elements['prerequisite-options'].elements.collect('option-code') {|node| node.get_text.to_s} unless option_node.elements['prerequisite-options'].blank?
        option = {
          :code => option_node.get_text('option-code').to_s,
          :name => option_node.get_text('option-name').to_s,
          :class => option_node.get_text('option-class').to_s,
          :prints_on_label => option_node.get_text('prints-on-label').to_s == "false" ? false : true,
          :qualifier_required => option_node.get_text('qualifier-required').to_s == "false" ? false : true
        }
        option[:conflicting_options] = conflicts if conflicts
        option[:prerequisite_options] = prereqs if prereqs

        option[:qualifier_max] = option_node.get_text("qualifier-max").to_s.to_i if option_node.get_text("qualifier-max")
        option
      end

      # rating

      def build_rates_request(origin, destination, line_items = [], options = {}, package = nil)
        xml =  XmlNode.new('mailing-scenario', :xmlns => "http://www.canadapost.ca/ws/ship/rate") do |node|
          node << customer_number_node(options)
          node << contract_id_node(options)
          node << quote_type_node(options)
          options_node = shipping_options_node(RATES_OPTIONS, options)
          node << options_node if options_node && !options_node.children.count.zero?
          node << parcel_node(line_items, package)
          node << origin_node(origin)
          node << destination_node(destination)
        end
        xml.to_s
      end

      def parse_rates_response(response, origin, destination)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        raise ActiveMerchant::Shipping::ResponseError, "No Quotes" unless doc.elements['price-quotes']

        quotes = doc.elements['price-quotes'].elements.collect('price-quote') {|node| node }
        rates = quotes.map do |node|
          service_name  = node.get_text("service-name").to_s
          service_code  = node.get_text("service-code").to_s
          total_price   = node.elements['price-details'].get_text("due").to_s
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
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        raise ActiveMerchant::Shipping::ResponseError, "No Tracking" unless root_node = doc.elements['tracking-detail']

        events = root_node.elements['significant-events'].elements.collect('occurrence') {|node| node }

        shipment_events  = build_tracking_events(events)
        change_date      = root_node.get_text('changed-expected-date').to_s
        expected_date    = root_node.get_text('expected-delivery-date').to_s
        dest_postal_code = root_node.get_text('destination-postal-id').to_s
        destination      = Location.new(:postal_code => dest_postal_code)
        origin           = Location.new({})        
        options = {
          :carrier                 => @@name,
          :service_name            => root_node.get_text('service-name').to_s,
          :expected_date           => Date.parse(expected_date),
          :changed_date            => change_date.blank? ? nil : Date.parse(change_date),
          :change_reason           => root_node.get_text('changed-expected-delivery-reason').to_s.strip,
          :destination_postal_code => root_node.get_text('destination-postal-id').to_s,
          :shipment_events         => shipment_events,
          :tracking_number         => root_node.get_text('pin').to_s,
          :origin                  => origin,
          :destination             => destination,
          :customer_number         => root_node.get_text('mailed-by-customer-number').to_s
        }
        
        CPPWSTrackingResponse.new(true, "", {}, options)
      end

      def build_tracking_events(events)
        events.map do |event|
          date      = event.get_text('event-date').to_s
          time      = event.get_text('event-time').to_s
          zone      = event.get_text('event-time-zone').to_s
          timestamp = DateTime.parse("#{date} #{time} #{zone}")
          time      = Time.utc(timestamp.utc.year, timestamp.utc.month, timestamp.utc.day, timestamp.utc.hour, timestamp.utc.min, timestamp.utc.sec)
          message   = event.get_text('event-description').to_s
          location  = [event.get_text('event-retail-name'), event.get_text('event-site'), event.get_text('event-province')].compact.join(", ")
          name      = event.get_text('event-identifier').to_s          
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
      def build_shipment_request(origin_hash, destination_hash, package, line_items = [], options = {})
        origin = Location.new(sanitize_zip(origin_hash))
        destination = Location.new(sanitize_zip(destination_hash))

        xml = XmlNode.new('non-contract-shipment', :xmlns => "http://www.canadapost.ca/ws/ncshipment") do |root_node|
          root_node << XmlNode.new('delivery-spec') do |node|
            node << shipment_service_code_node(options)
            node << shipment_sender_node(origin, options)
            node << shipment_destination_node(destination, options)
            options_node = shipment_options_node(options)
            node << shipment_options_node(options) if options_node && !options_node.children.count.zero?
            node << shipment_parcel_node(package)
            node << shipment_notification_node(options)
            node << shipment_preferences_node(options)
            node << references_node(options)             # optional > user defined custom notes
            node << shipment_customs_node(destination, line_items, options)
            # COD Remittance defaults to sender
          end
        end
        xml.to_s
      end

      def shipment_service_code_node(options)
        XmlNode.new('service-code', options[:service])
      end

      def shipment_sender_node(location, options)
        XmlNode.new('sender') do |node|
          node << XmlNode.new('name', location.name)
          node << XmlNode.new('company', location.company) if location.company.present?
          node << XmlNode.new('contact-phone', location.phone)
          node << XmlNode.new('address-details') do |innernode|
            innernode << XmlNode.new('address-line-1', location.address1)
            address2 = [location.address2, location.address3].reject(&:blank?).join(", ")
            innernode << XmlNode.new('address-line-2', address2) unless address2.blank?
            innernode << XmlNode.new('city', location.city)
            innernode << XmlNode.new('prov-state', location.province)     
            #innernode << XmlNode.new('country-code', location.country_code)
            innernode << XmlNode.new('postal-zip-code', location.postal_code)
          end
        end
      end

      def shipment_destination_node(location, options)
        XmlNode.new('destination') do |node|
          node << XmlNode.new('name', location.name)
          node << XmlNode.new('company', location.company) if location.company.present?
          node << XmlNode.new('client-voice-number', location.phone)
          node << XmlNode.new('address-details') do |innernode|
            innernode << XmlNode.new('address-line-1', location.address1)
            address2 = [location.address2, location.address3].reject(&:blank?).join(", ")
            innernode << XmlNode.new('address-line-2', address2) unless address2.blank?
            innernode << XmlNode.new('city', location.city)
            innernode << XmlNode.new('prov-state', location.province) unless location.province.blank?
            innernode << XmlNode.new('country-code', location.country_code)
            innernode << XmlNode.new('postal-zip-code', location.postal_code)
          end
        end
      end

      def shipment_options_node(options)
          shipping_options_node(SHIPPING_OPTIONS, options)
      end

      def shipment_notification_node(options)
        return unless options[:notification_email]
        XmlNode.new('notification') do |node|
          node << XmlNode.new('email', options[:notification_email])
          node << XmlNode.new('on-shipment', true)
          node << XmlNode.new('on-exception', true)
          node << XmlNode.new('on-delivery', true)
        end
      end

      def shipment_preferences_node(options)
        XmlNode.new('preferences') do |node|
          node << XmlNode.new('show-packing-instructions', options[:packing_instructions] || true)
          node << XmlNode.new('show-postage-rate', options[:show_postage_rate] || false)          
          node << XmlNode.new('show-insured-value', true)
        end
      end

      def references_node(options)
        # custom values
        # XmlNode.new('references') do |node|
        # end
      end

      def shipment_customs_node(destination, line_items, options)
        return unless destination.country_code != 'CA'

        XmlNode.new('customs') do |node|
          currency = options[:currency] || "CAD"
          node << XmlNode.new('currency',currency)
          node << XmlNode.new('conversion-from-cad',options[:conversion_from_cad].to_s) if currency != 'CAD' && options[:conversion_from_cad]
          node << XmlNode.new('reason-for-export','SOG') # SOG - Sale of Goods
          node << XmlNode.new('other-reason',options[:customs_other_reason]) if (options[:customs_reason_for_export] && options[:customs_other_reason])
          node << XmlNode.new('additional-customs-info',options[:customs_addition_info]) if options[:customs_addition_info]
          node << XmlNode.new('sku-list') do |sku|
            line_items.each do |line_item|
              sku << XmlNode.new('item') do |item|
                item << XmlNode.new('hs-tariff-code', line_item.hs_code) if line_item.hs_code && !line_item.hs_code.empty?
                item << XmlNode.new('sku', line_item.sku) if line_item.sku && !line_item.sku.empty?
                item << XmlNode.new('customs-description', line_item.name)
                item << XmlNode.new('unit-weight', '%#2.3f' % sanitize_weight_kg(line_item.kg))
                item << XmlNode.new('customs-value-per-unit', '%.2f' % sanitize_price_from_cents(line_item.value_per_unit))
                item << XmlNode.new('customs-number-of-units', line_item.quantity)
                item << XmlNode.new('country-of-origin', line_item.options[:country_of_origin]) if line_item.options && line_item.options[:country_of_origin] && !line_item.options[:country_of_origin].empty?
                item << XmlNode.new('province-of-origin', line_item.options[:province_of_origin]) if line_item.options && line_item.options[:province_of_origin] && !line_item.options[:province_of_origin].empty?
              end
            end
          end
          
        end
      end

      def shipment_parcel_node(package, options ={})
        weight = sanitize_weight_kg(package.kilograms.to_f)
        XmlNode.new('parcel-characteristics') do |el|
          el << XmlNode.new('weight', "%#2.3f" % weight)
          pkg_dim = package.cm
          if pkg_dim && !pkg_dim.select{|x| x != 0}.empty?
            el << XmlNode.new('dimensions') do |dim|
              dim << XmlNode.new('length', '%.1f' % ((pkg_dim[2]*10).round / 10.0)) if pkg_dim.size >= 3
              dim << XmlNode.new('width', '%.1f' % ((pkg_dim[1]*10).round / 10.0)) if pkg_dim.size >= 2
              dim << XmlNode.new('height', '%.1f' % ((pkg_dim[0]*10).round / 10.0)) if pkg_dim.size >= 1
            end
          end
          el << XmlNode.new('document', false)
          el << XmlNode.new('mailing-tube', package.tube?)
          el << XmlNode.new('unpackaged', package.unpackaged?)
        end
      end


      def parse_shipment_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        raise ActiveMerchant::Shipping::ResponseError, "No Shipping" unless root_node = doc.elements['non-contract-shipment-info']      
        options = {
          :shipping_id      => root_node.get_text('shipment-id').to_s,
          :tracking_number  => root_node.get_text('tracking-pin').to_s,
          :details_url      => root_node.elements["links/link[@rel='details']"].attributes['href'],
          :label_url        => root_node.elements["links/link[@rel='label']"].attributes['href'],
          :receipt_url      => root_node.elements["links/link[@rel='receipt']"].attributes['href']
        }
        CPPWSShippingResponse.new(true, "", {}, options)
      end

      def parse_register_token_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        raise ActiveMerchant::Shipping::ResponseError, "No Registration Token" unless root_node = doc.elements['token']      
        options = {
          :token_id => root_node.get_text('token-id').to_s
        }
        CPPWSRegisterResponse.new(true, "", {}, options)
      end

      def parse_merchant_details_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        raise "No Merchant Info" unless root_node = doc.elements['merchant-info']
        raise "No Merchant Info" if root_node.get_text('customer-number').blank?
        options = {
          :customer_number => root_node.get_text('customer-number').to_s,
          :contract_number => root_node.get_text('contract-number').to_s,
          :username => root_node.get_text('merchant-username').to_s,
          :password => root_node.get_text('merchant-password').to_s,
          :has_default_credit_card => root_node.get_text('has-default-credit-card') == 'true' ? true : false
        }
        CPPWSMerchantDetailsResponse.new(true, "", {}, options)
      end

      def parse_shipment_receipt_response(response)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        root = doc.elements['non-contract-shipment-receipt']
        cc_details_node = root.elements['cc-receipt-details']
        service_standard_node = root.elements['service-standard']
        receipt = {
          :final_shipping_point => root.get_text("final-shipping-point").to_s,
          :shipping_point_name => root.get_text("shipping-point-name").to_s,
          :service_code => root.get_text("service-code").to_s,
          :rated_weight => root.get_text("rated-weight").to_s.to_f,
          :base_amount => root.get_text("base-amount").to_s.to_f,
          :pre_tax_amount => root.get_text("pre-tax-amount").to_s.to_f,
          :gst_amount => root.get_text("gst-amount").to_s.to_f,
          :pst_amount => root.get_text("pst-amount").to_s.to_f,
          :hst_amount => root.get_text("hst-amount").to_s.to_f,
          :charge_amount => cc_details_node.get_text("charge-amount").to_s.to_f,
          :currency => cc_details_node.get_text("currency").to_s,
          :expected_transit_days => service_standard_node.get_text("expected-transit-time").to_s.to_i,
          :expected_delivery_date => service_standard_node.get_text("expected-delivery-date").to_s
        }
        option_nodes = root.elements['priced-options'].elements.collect('priced-option') {|node| node} unless root.elements['priced-options'].blank?
        receipt[:priced_options] = option_nodes.inject({}) do |result, node|
          result[node.get_text("option-code").to_s] = node.get_text("option-price").to_s.to_f
          result
        end
        receipt
      end

      def error_response(response, response_klass)
        doc = REXML::Document.new(REXML::Text::unnormalize(response))
        messages = doc.elements['messages'].elements.collect('message') {|node| node }
        message = messages.map {|m| m.get_text('description').to_s }.join(", ")
        code = messages.map {|m| m.get_text('code').to_s }.join(", ")
        response_klass.new(false, message, {}, {:carrier => @@name, :code => code})
      end

      def log(msg)
        logger.debug(msg) if logger
      end

      private

      def customer_credentials_valid?(credentials)
        (credentials.keys & [:customer_api_key, :customer_secret]).any?
      end

      def encoded_authorization(customer_credentials = {})
        if customer_credentials_valid?(customer_credentials)
          "Basic %s" % ActiveSupport::Base64.encode64("#{customer_credentials[:customer_api_key]}:#{customer_credentials[:customer_secret]}")
        else
          "Basic %s" % ActiveSupport::Base64.encode64("#{@options[:api_key]}:#{@options[:secret]}")
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

      def customer_number_node(options)
        XmlNode.new("customer-number", options[:customer_number])
      end

      def contract_id_node(options)
        XmlNode.new("contract-id", options[:contract_id]) if options[:contract_id]
      end

      def quote_type_node(options)
        XmlNode.new("quote-type", 'commercial')
      end

      def parcel_node(line_items, package = nil, options ={})
        weight = sanitize_weight_kg(package && !package.kilograms.zero? ? package.kilograms.to_f : line_items.sum(&:kilograms).to_f)
        XmlNode.new('parcel-characteristics') do |el|
          el << XmlNode.new('weight', "%#2.3f" % weight)
          if package
            pkg_dim = package.cm
            if pkg_dim && !pkg_dim.select{|x| x != 0}.empty?
              el << XmlNode.new('dimensions') do |dim|
                dim << XmlNode.new('length', '%.1f' % ((pkg_dim[2]*10).round / 10.0)) if pkg_dim.size >= 3
                dim << XmlNode.new('width', '%.1f' % ((pkg_dim[1]*10).round / 10.0)) if pkg_dim.size >= 2
                dim << XmlNode.new('height', '%.1f' % ((pkg_dim[0]*10).round / 10.0)) if pkg_dim.size >= 1
              end
            end
          end
          el << XmlNode.new('mailing-tube', line_items.any?(&:tube?))
          el << XmlNode.new('oversized', true) if line_items.any?(&:oversized?)
          el << XmlNode.new('unpackaged', line_items.any?(&:unpackaged?))
        end
      end

      def origin_node(location_hash)
        origin = Location.new(sanitize_zip(location_hash))
        XmlNode.new("origin-postal-code", origin.zip)
      end

      def destination_node(location_hash)
        destination = Location.new(sanitize_zip(location_hash))
        case destination.country_code
          when 'CA'
            XmlNode.new('destination') do |node|
              node << XmlNode.new('domestic') do |x|
                x << XmlNode.new('postal-code', destination.postal_code)
              end
            end

          when 'US'
            XmlNode.new('destination') do |node|
              node << XmlNode.new('united-states') do |x|
                x << XmlNode.new('zip-code', destination.postal_code)
              end
            end

          else
            XmlNode.new('destination') do |dest|
              dest << XmlNode.new('international') do |dom|
                dom << XmlNode.new('country-code', destination.country_code)
              end
            end
        end
      end

      def shipping_options_node(available_options, options = {})
        return if (options.symbolize_keys.keys & available_options).empty?
        XmlNode.new('options') do |el|

          if options[:cod] && options[:cod_amount]
            el << XmlNode.new('option') do |opt|
              opt << XmlNode.new('option-code', 'COD')
              opt << XmlNode.new('option-amount', options[:cod_amount])
              opt << XmlNode.new('option-qualifier-1', options[:cod_includes_shipping]) unless options[:cod_includes_shipping].blank?
              opt << XmlNode.new('option-qualifier-2', options[:cod_method_of_payment]) unless options[:cod_method_of_payment].blank?
            end
          end

          if options[:cov]
            el << XmlNode.new('option') do |opt|
              opt << XmlNode.new('option-code', 'COV')
              opt << XmlNode.new('option-amount', options[:cov_amount]) unless options[:cov_amount].blank?
            end
          end

          if options[:d2po]
            el << XmlNode.new('option') do |opt|
              opt << XmlNode.new('option-code', 'D2PO')
              opt << XmlNode.new('option-qualifier-2'. options[:d2po_office_id]) unless options[:d2po_office_id].blank?
            end
          end

          [:so, :dc, :pa18, :pa19, :hfp, :dns, :lad, :rase, :rts, :aban].each do |code|
            if options[code]
              el << XmlNode.new('option') do |opt|
                opt << XmlNode.new('option-code', code.to_s.upcase)
              end
            end
          end
        end
      end


      
      def expected_date_from_node(node)
        if service = node.elements['service-standard']
          expected_date = service.get_text("expected-delivery-date").to_s
        else
          expected_date = nil
        end
      end

      def sanitize_zip(hash)
        [:postal_code, :zip].each do |attr|
          hash[attr].gsub!(/\s+/,'') if hash[attr]
        end
        hash
      end

      def sanitize_weight_kg(kg)
        return kg == 0 ? 0.001 : kg;
      end

      def sanitize_price_from_cents(value)
        return value == 0 ? 0.01 : value.round / 100.0
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
        "http://www.canadapost.ca/cpotools/apps/drc/merchant?return-url=#{CGI::escape(return_url)}&token-id=#{token_id}&platform-id=#{customer_id}"
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

    # custom errors
    class InvalidPinFormatError < StandardError; end
    class MissingCustomerNumberError < StandardError; end
    class MissingShippingNumberError < StandardError; end
    class MissingTokenIdError < StandardError; end

  end
end
