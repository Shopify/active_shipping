require 'cgi'

module ActiveMerchant
  module Shipping
    
    class CanadaPost < Carrier
      
      # NOTE!
      # A Merchant CPC Id must be assigned to you by Canada Post
      # CPC_DEMO_XML is just a public domain account for testing
      
      class CanadaPostRateResponse < RateResponse
        
        attr_reader :boxes, :postal_outlets
        
        def initialize(success, message, params = {}, options = {})
          @boxes = options[:boxes]
          @postal_outlets = options[:postal_outlets]
          super
        end
        
      end
      
      cattr_reader :name, :name_french
      @@name = "Canada Post"
      @@name_french = "Postes Canada"
      
      Box = Struct.new(:name, :weight, :expediter_weight, :length, :width, :height, :packedItems)
      PackedItem = Struct.new(:quantity, :description)
      PostalOutlet = Struct.new(:sequence_no, :distance, :name, :business_name, :postal_address, :business_hours)
      
      DEFAULT_TURN_AROUND_TIME = 24
      URL = "http://sellonline.canadapost.ca:30000"
      DOCTYPE = '<!DOCTYPE eparcel SYSTEM "http://sellonline.canadapost.ca/DevelopersResources/protocolV3/eParcel.dtd">'      
      
      RESPONSE_CODES = {
       '1'     =>	"All calculation was done",
       '2'     =>	"Default shipping rates are returned due to a problem during the processing of the request.",
       '-2'    => "Missing argument when calling module",
       '-5'	   => "No Item to ship",
       '-6'	   => "Illegal Item weight",
       '-7'	   => "Illegal item dimension",
       '-12'   => "Can't open IM config file",
       '-13'   => "Can't create log files",
       '-15'   => "Invalid config file format",
       '-102'  => "Invalid socket connection",
       '-106'  => "Can't connect to server",
       '-1000' => "Unknow request type sent by client",
       '-1002' => "MAS Timed out",
       '-1004' => "Socket communication break",
       '-1005' => "Did not receive required data on socket.",
       '-2000' => "Unable to estabish socket connection with RSSS",
       '-2001' => "Merchant Id not found on server",
       '-2002' => "One or more parameter was not sent by the IM to the MAS",
       '-2003' => "Did not receive required data on socket.",
       '-2004' => "The request contains to many items to process it.",
       '-2005' => "The request received on socket is larger than the maximum allowed.",
       '-3000' => "Origin Postal Code is illegal",
       '-3001' => "Destination Postal Code/State Name/ Country  is illegal",
       '-3002' => "Parcel too large to be shipped with CPC",
       '-3003' => "Parcel too small to be shipped with CPC",
       '-3004' => "Parcel too heavy to be shipped with CPC",
       '-3005' => "Internal error code returned by the rating DLL",
       '-3006' => "The pick up time format is invalid or not defined.",
       '-4000' => "Volumetric internal error",
       '-4001' => "Volumetric time out calculation error.",
       '-4002' => "No bins provided to the volumetric engine.",
       '-4003' => "No items provided to the volumetric engine.",
       '-4004' => "Item is too large to be packed",
       '-4005' => "Number of item more than maximum allowed",
       '-5000' => "XML Parsing error",
       '-5001' => "XML Tag not found",
       '-5002' => "Node Value Number format error",
       '-5003' => "Node value is empty",
       '-5004' => "Unable to create/parse XML Document",
       '-6000' => "Unable to open the database",
       '-6001' => "Unable to read from the database",
       '-6002' => "Unable to write to the database",
       '-50000' => "Internal problem - Please contact Sell Online Help Desk"
      }
      
      NON_ISO_COUNTRY_NAMES = {
        'Russian Federation' => 'Russia'
      }


      def requirements
        [:login]
      end
      
      def find_rates(origin, destination, line_items = [], options = {})
        rate_request = build_rate_request(origin, destination, line_items, options)
        commit(rate_request, origin, destination, options)
      end
      
      def maximum_weight
        Mass.new(30, :kilograms)
      end
      
      def self.default_location
        {
          :country     => 'CA',
          :province    => 'ON',
          :city        => 'Ottawa',
          :address1    => '61A York St',
          :postal_code => 'K1N5T2'
        }
      end

      protected
      
      def commit(request, origin, destination, options = {})
        response = parse_rate_response(ssl_post(URL, request), origin, destination, options)
      end
      
      private
      
      def build_rate_request(origin, destination, line_items = [], options = {})
        line_items = [line_items] if !line_items.is_a?(Array)
        origin = origin.is_a?(Location) ? origin : Location.new(origin)
        destination = destination.is_a?(Location) ? destination : Location.new(destination)

        xml_request = XmlNode.new('eparcel') do |root_node|
          root_node << XmlNode.new('language', @options[:french] ? 'fr' : 'en')
          root_node << XmlNode.new('ratesAndServicesRequest') do |request|

            request << XmlNode.new('merchantCPCID', @options[:login])
            request << XmlNode.new('fromPostalCode', origin.postal_code)
            request << XmlNode.new('turnAroundTime', options[:turn_around_time] ? options[:turn_around_time] : DEFAULT_TURN_AROUND_TIME)
            request << XmlNode.new('itemsPrice', dollar_amount(line_items.sum(&:value)))

            #line items
            request << build_line_items(line_items)

            #delivery info
            #NOTE: These tags MUST be after line items
            request << XmlNode.new('city', destination.city)
            request << XmlNode.new('provOrState', destination.province)
            request << XmlNode.new('country', handle_non_iso_country_names(destination.country))
            request << XmlNode.new('postalCode', destination.postal_code)
          end
        end

        DOCTYPE + xml_request.to_s
      end

      def parse_rate_response(response, origin, destination, options = {})
        xml = REXML::Document.new(response)
        success = response_success?(xml)
        message = response_message(xml)

        rate_estimates = []
        boxes = []
        if success
          xml.elements.each('eparcel/ratesAndServicesResponse/product') do |product|
            service_name = (@options[:french] ? @@name_french : @@name) + " " + product.get_text('name').to_s
            service_code = product.attribute('id').to_s

            rate_estimates << RateEstimate.new(origin, destination, @@name, service_name,
              :service_code => service_code,
              :total_price => product.get_text('rate').to_s,
              :currency => 'CAD',
              :delivery_range => [product.get_text('deliveryDate').to_s] * 2
            )
          end

          boxes = xml.elements.collect('eparcel/ratesAndServicesResponse/packing/box') do |box|
            b = Box.new
            b.packedItems = []
            b.name = box.get_text('name').to_s
            b.weight = box.get_text('weight').to_s.to_f
            b.expediter_weight = box.get_text('expediterWeight').to_s.to_f
            b.length = box.get_text('length').to_s.to_f
            b.width = box.get_text('width').to_s.to_f
            b.height = box.get_text('height').to_s.to_f
            b.packedItems = box.elements.collect('packedItem') do |item|
              p = PackedItem.new
              p.quantity = item.get_text('quantity').to_s.to_i
              p.description = item.get_text('description').to_s
              p
            end
            b
          end

          postal_outlets = xml.elements.collect('eparcel/ratesAndServicesResponse/nearestPostalOutlet') do |outlet|
            postal_outlet = PostalOutlet.new
            postal_outlet.sequence_no    = outlet.get_text('postalOutletSequenceNo').to_s
            postal_outlet.distance       = outlet.get_text('distance').to_s
            postal_outlet.name           = outlet.get_text('outletName').to_s
            postal_outlet.business_name  = outlet.get_text('businessName').to_s

            postal_outlet.postal_address = Location.new({
              :address1     => outlet.get_text('postalAddress/addressLine').to_s,
              :postal_code  => outlet.get_text('postalAddress/postal_code').to_s,
              :city         => outlet.get_text('postalAddress/municipality').to_s,
              :province     => outlet.get_text('postalAddress/province').to_s,
              :country      => 'Canada',
              :phone_number => outlet.get_text('phoneNumber').to_s
            })

            postal_outlet.business_hours = outlet.elements.collect('businessHours') do |hour|
              { :day_of_week => hour.get_text('dayOfWeek').to_s, :time => hour.get_text('time').to_s }
            end

            postal_outlet
          end
        end

        CanadaPostRateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :boxes => boxes, :postal_outlets => postal_outlets)
      end

      def response_success?(xml)
        value = xml.get_text('eparcel/ratesAndServicesResponse/statusCode').to_s
        value == '1' || value == '2'
      end
      
      def response_message(xml)
        xml.get_text('eparcel/ratesAndServicesResponse/statusMessage').to_s
      end
      
      # <!-- List of items in the shopping    -->
      # <!-- cart                             -->
      # <!-- Each item is defined by :        -->
      # <!--   - quantity    (mandatory)      -->
      # <!--   - size        (mandatory)      -->
      # <!--   - weight      (mandatory)      -->
      # <!--   - description (mandatory)      -->
      # <!--   - ready to ship (optional)     -->
      
      def build_line_items(line_items)
        xml_line_items = XmlNode.new('lineItems') do |line_items_node|
          
          line_items.each do |line_item|
            
            line_items_node << XmlNode.new('item') do |item|
              item << XmlNode.new('quantity', 1)
              item << XmlNode.new('weight', line_item.kilograms)
              item << XmlNode.new('length', line_item.cm(:length).to_s)
              item << XmlNode.new('width', line_item.cm(:width).to_s)
              item << XmlNode.new('height', line_item.cm(:height).to_s)
              item << XmlNode.new('description', line_item.options[:description] || ' ')
              item << XmlNode.new('readyToShip', line_item.options[:ready_to_ship] || nil)
              
              # By setting the 'readyToShip' tag to true, Sell Online will not pack this item in the boxes defined in the merchant profile.
            end
          end
        end
        
        xml_line_items
      end
      
      def dollar_amount(cents)
        "%0.2f" % (cents / 100.0)
      end
      
      def handle_non_iso_country_names(country)
        NON_ISO_COUNTRY_NAMES[country.to_s] || country
      end
    end
  end
end
