module ActiveShipping
  class Shipwire < Carrier
    self.retry_safe = true

    cattr_reader :name
    @@name = "Shipwire"

    URL = 'https://api.shipwire.com/exec/RateServices.php'
    SCHEMA_URL = 'http://www.shipwire.com/exec/download/RateRequest.dtd'
    WAREHOUSES = { 'CHI' => 'Chicago',
                   'LAX' => 'Los Angeles',
                   'REN' => 'Reno',
                   'VAN' => 'Vancouver',
                   'TOR' => 'Toronto',
                   'UK'  => 'United Kingdom'
                 }

    CARRIERS = ["UPS", "USPS", "FedEx", "Royal Mail", "Parcelforce", "Pharos", "Eurotrux", "Canada Post", "DHL"]

    SUCCESS = "OK"
    SUCCESS_MESSAGE = "Successfully received the shipping rates"
    NO_RATES_MESSAGE = "No shipping rates could be found for the destination address"
    REQUIRED_OPTIONS = [:login, :password].freeze

    def find_rates(origin, destination, packages, options = {})
      requires!(options, :items)
      commit(origin, destination, options)
    end

    def valid_credentials?
      location = self.class.default_location
      find_rates(location, location, Package.new(100, [5, 15, 30]),
                 :items => [{ :sku => '', :quantity => 1 }]
      )
    rescue ActiveShipping::ResponseError
      true
    rescue ActiveUtils::ResponseError => e
      e.response.code != '401'
    end

    private

    def requirements
      REQUIRED_OPTIONS
    end

    def build_request(destination, options)
      Nokogiri::XML::Builder.new do |xml|
        xml.doc.create_internal_subset('RateRequest', nil, SCHEMA_URL)
        xml.RateRequest do
          add_credentials(xml)
          add_order(xml, destination, options)
        end
      end.to_xml
    end

    def add_credentials(xml)
      xml.EmailAddress @options[:login]
      xml.Password @options[:password]
    end

    def add_order(xml, destination, options)
      xml.Order :id => options[:order_id] do
        xml.Warehouse options[:warehouse] || '00'

        add_address(xml, destination)
        Array(options[:items]).each_with_index do |line_item, index|
          add_item(xml, line_item, index)
        end
      end
    end

    def add_address(xml, destination)
      xml.AddressInfo :type => 'Ship' do
        if destination.name.present?
          xml.Name do
            xml.Full destination.name
          end
        end
        xml.Address1 destination.address1
        xml.Address2 destination.address2 unless destination.address2.blank?
        xml.Address3 destination.address3 unless destination.address3.blank?
        xml.Company destination.company unless destination.company.blank?
        xml.City destination.city
        xml.State destination.state unless destination.state.blank?
        xml.Country destination.country_code
        xml.Zip destination.zip  unless destination.zip.blank?
      end
    end

    # Code is limited to 12 characters
    def add_item(xml, item, index)
      xml.Item :num => index do
        xml.Code item[:sku]
        xml.Quantity item[:quantity]
      end
    end

    def commit(origin, destination, options)
      request = build_request(destination, options)
      save_request(request)

      response = parse( ssl_post(URL, "RateRequestXML=#{CGI.escape(request)}") )

      RateResponse.new(response["success"], response["message"], response,
                       :xml     => response,
                       :rates   => build_rate_estimates(response, origin, destination),
                       :request => last_request
      )
    end

    def build_rate_estimates(response, origin, destination)
      response["rates"].collect do |quote|
        RateEstimate.new(origin, destination, carrier_for(quote["service"]), quote["service"],
                         :service_code    => quote["method"],
                         :total_price     => quote["cost"],
                         :currency        => quote["currency"],
                         :delivery_range  => [timestamp_from_business_day(quote["delivery_min"]),
                                              timestamp_from_business_day(quote["delivery_max"])]
        )
      end
    end

    def carrier_for(service)
      CARRIERS.dup.find { |carrier| service.to_s =~ /^#{carrier}/i } || service.to_s.split(" ").first
    end

    def parse(xml)
      response = {}
      response["rates"] = []

      document = Nokogiri.XML(xml)

      response["status"] = parse_child_text(document.root, "Status")

      document.root.xpath("Order/Quotes/Quote").each do |e|
        rate = {}
        rate["method"]    = e["method"]
        rate["warehouse"] = parse_child_text(e, "Warehouse")
        rate["service"]   = parse_child_text(e, "Service")
        rate["cost"]      = parse_child_text(e, "Cost")
        rate["currency"]  = parse_child_attribute(e, "Cost", "currency")
        if delivery_estimate = e.at("DeliveryEstimate")
          rate["delivery_min"]  = parse_child_text(delivery_estimate, "Minimum").to_i
          rate["delivery_max"]  = parse_child_text(delivery_estimate, "Maximum").to_i
        end
        response["rates"] << rate
      end

      if response["status"] == SUCCESS && response["rates"].any?
        response["success"] = true
        response["message"] = SUCCESS_MESSAGE
      elsif response["status"] == SUCCESS && response["rates"].empty?
        response["success"] = false
        response["message"] = NO_RATES_MESSAGE
      else
        response["success"] = false
        response["message"] = parse_child_text(document.root, "ErrorMessage")
      end

      response
    rescue NoMethodError => e
      raise ActiveShipping::ResponseContentError.new(e, xml)
    end

    def parse_child_text(parent, name)
      if element = parent.at(name)
        element.text
      end
    end

    def parse_child_attribute(parent, name, attribute)
      if element = parent.at(name)
        element[attribute]
      end
    end
  end
end
