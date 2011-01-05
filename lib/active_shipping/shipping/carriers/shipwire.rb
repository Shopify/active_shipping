require 'cgi'
require 'builder'

module ActiveMerchant
  module Shipping
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
                   
      CARRIERS = [ "UPS", "USPS", "FedEx", "Royal Mail", "Parcelforce", "Pharos", "Eurotrux", "Canada Post", "DHL" ]
                   
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
        find_rates(location, location, Package.new(100, [5,15,30]),
          :items => [ { :sku => '', :quantity => 1 } ]
        )
      rescue ActiveMerchant::Shipping::ResponseError => e
        e.message != "Could not verify e-mail/password combination"
      end
      
      private
      def requirements
        REQUIRED_OPTIONS
      end
      
      def build_request(destination, options)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.declare! :DOCTYPE, :RateRequest, :SYSTEM, SCHEMA_URL
        xml.tag! 'RateRequest' do
          add_credentials(xml)
          add_order(xml, destination, options) 
        end
        xml.target!
      end
      
      def add_credentials(xml)
        xml.tag! 'EmailAddress', @options[:login]
        xml.tag! 'Password', @options[:password]
      end

      def add_order(xml, destination, options)
        xml.tag! 'Order', :id => options[:order_id] do
          xml.tag! 'Warehouse', options[:warehouse] || '00'

          add_address(xml, destination)
          Array(options[:items]).each_with_index do |line_item, index|
            add_item(xml, line_item, index)
          end
        end
      end

      def add_address(xml, destination)
        xml.tag! 'AddressInfo', :type => 'Ship' do
          xml.tag! 'Name', destination.name unless destination.name.blank?
          xml.tag! 'Address1', destination.address1
          xml.tag! 'Address2', destination.address2 unless destination.address2.blank?
          xml.tag! 'Address3', destination.address3 unless destination.address3.blank?
          xml.tag! 'City', destination.city
          xml.tag! 'State', destination.state unless destination.state.blank?
          xml.tag! 'Country', destination.country_code
          xml.tag! 'Zip', destination.zip  unless destination.zip.blank?
        end
      end
      
     # Code is limited to 12 characters
      def add_item(xml, item, index)
        xml.tag! 'Item', :num => index do
          xml.tag! 'Code', item[:sku]
          xml.tag! 'Quantity', item[:quantity]
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
            :service_code  => quote["method"],
            :total_price   => quote["cost"],
            :currency      => quote["currency"]
          )
        end
      end
      
      def carrier_for(service)
        CARRIERS.dup.find{ |carrier| service.to_s =~ /^#{carrier}/i } || service.to_s.split(" ").first
      end

      def parse(xml)
        response = {}
        response["rates"] = []

        document = REXML::Document.new(xml)
    
        response["status"] = parse_child_text(document.root, "Status")
             
        document.root.elements.each("Order/Quotes/Quote") do |e|
          rate = {}
          rate["method"]    = e.attributes["method"]
          rate["warehouse"] = parse_child_text(e, "Warehouse")
          rate["service"]   = parse_child_text(e, "Service")
          rate["cost"]      = parse_child_text(e, "Cost")
          rate["currency"]  = parse_child_attribute(e, "Cost", "currency")
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
      end
      
      def parse_child_text(parent, name)
        if element = parent.elements[name]
          element.text
        end
      end
      
      def parse_child_attribute(parent, name, attribute)
        if element = parent.elements[name]
          element.attributes[attribute]
        end
      end      
    end
  end
end