module ActiveShipping
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

    URL = "http://sellonline.canadapost.ca:30000"
    DTD_NAME = 'eparcel'
    DTD_URI  = "http://sellonline.canadapost.ca/DevelopersResources/protocolV3/eParcel.dtd"

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
      Measured::Weight.new(30, :kg)
    end

    def maximum_address_field_length
      # https://www.canadapost.ca/cpo/mc/business/productsservices/developers/services/shippingmanifest/createshipment.jsf
      44
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
      parse_rate_response(ssl_post(URL, request), origin, destination, options)
    end

    private

    def generate_xml(&block)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.doc.create_internal_subset(DTD_NAME, nil, DTD_URI)
        yield(xml)
      end
      builder.to_xml
    end

    def build_rate_request(origin, destination, line_items = [], options = {})
      line_items  = [line_items] unless line_items.is_a?(Array)
      origin      = origin.is_a?(Location) ? origin : Location.new(origin)
      destination = destination.is_a?(Location) ? destination : Location.new(destination)

      generate_xml do |xml|
        xml.eparcel do
          xml.language(@options[:french] ? 'fr' : 'en')
          xml.ratesAndServicesRequest do
            xml.merchantCPCID(@options[:login])
            xml.fromPostalCode(origin.postal_code)
            xml.turnAroundTime(options[:turn_around_time]) if options[:turn_around_time]
            xml.itemsPrice(dollar_amount(line_items.map(&:value).compact.sum))

            build_line_items(xml, line_items)

            xml.city(destination.city)
            xml.provOrState(destination.province)
            xml.country(handle_non_iso_country_names(destination.country))
            xml.postalCode(destination.postal_code)
          end
        end
      end
    end

    def parse_rate_response(response, origin, destination, options = {})
      xml = Nokogiri.XML(response)
      success = response_success?(xml)
      message = response_message(xml)

      rate_estimates = []
      boxes = []
      if success
        xml.xpath('eparcel/ratesAndServicesResponse/product').each do |product|
          service_name = (@options[:french] ? @@name_french : @@name) + " " + product.at('name').text
          service_code = product['id']

          rate_estimates << RateEstimate.new(origin, destination, @@name, service_name,
                                             :service_code => service_code,
                                             :total_price => product.at('rate').text,
                                             :currency => 'CAD',
                                             :shipping_date => product.at('shippingDate').text,
                                             :delivery_range => [product.at('deliveryDate').text] * 2
          )
        end

        boxes = xml.xpath('eparcel/ratesAndServicesResponse/packing/box').map do |box|
          b = Box.new
          b.packedItems = []
          b.name = box.at('name').text
          b.weight = box.at('weight').text.to_f
          b.expediter_weight = box.at('expediterWeight').text.to_f
          b.length = box.at('length').text.to_f
          b.width = box.at('width').text.to_f
          b.height = box.at('height').text.to_f
          b.packedItems = box.xpath('packedItem').map do |item|
            p = PackedItem.new
            p.quantity = item.at('quantity').text.to_i
            p.description = item.at('description').text
            p
          end
          b
        end

        postal_outlets = xml.xpath('eparcel/ratesAndServicesResponse/nearestPostalOutlet').map do |outlet|
          postal_outlet = PostalOutlet.new
          postal_outlet.sequence_no    = outlet.at('postalOutletSequenceNo').text
          postal_outlet.distance       = outlet.at('distance').text
          postal_outlet.name           = outlet.at('outletName').text
          postal_outlet.business_name  = outlet.at('businessName').text

          postal_outlet.postal_address = Location.new(
            :address1     => outlet.at('postalAddress/addressLine').text,
            :postal_code  => outlet.at('postalAddress/postal_code').text,
            :city         => outlet.at('postalAddress/municipality').text,
            :province     => outlet.at('postalAddress/province').text,
            :country      => 'Canada',
            :phone_number => outlet.at('phoneNumber').text
          )

          postal_outlet.business_hours = outlet.elements.collect('businessHours') do |hour|
            { :day_of_week => hour.at('dayOfWeek').text, :time => hour.at('time').text }
          end

          postal_outlet
        end
      end

      CanadaPostRateResponse.new(success, message, Hash.from_xml(response), :rates => rate_estimates, :xml => response, :boxes => boxes, :postal_outlets => postal_outlets)
    end

    def response_success?(xml)
      return false unless xml.at('eparcel/error').nil?

      value = xml.at('eparcel/ratesAndServicesResponse/statusCode').text
      value == '1' || value == '2'
    end

    def response_message(xml)
      if response_success?(xml)
        xml.at('eparcel/ratesAndServicesResponse/statusMessage').text
      else
        xml.at('eparcel/error/statusMessage').text
      end
    end

    # <!-- List of items in the shopping    -->
    # <!-- cart                             -->
    # <!-- Each item is defined by :        -->
    # <!--   - quantity    (mandatory)      -->
    # <!--   - size        (mandatory)      -->
    # <!--   - weight      (mandatory)      -->
    # <!--   - description (mandatory)      -->
    # <!--   - ready to ship (optional)     -->

    def build_line_items(xml, line_items)
      xml.lineItems do
        line_items.each do |line_item|
          xml.item do
            xml.quantity(1)
            xml.weight(line_item.kilograms)
            xml.length(line_item.cm(:length).to_s)
            xml.width(line_item.cm(:width).to_s)
            xml.height(line_item.cm(:height).to_s)
            xml.description(line_item.options[:description] || ' ')
            xml.readyToShip(line_item.options[:ready_to_ship] || nil)
            # By setting the 'readyToShip' tag to true, Sell Online will not pack this item in the boxes defined in the merchant profile.
          end
        end
      end
    end

    def dollar_amount(cents)
      "%0.2f" % (cents / 100.0)
    end

    def handle_non_iso_country_names(country)
      NON_ISO_COUNTRY_NAMES[country.to_s] || country
    end
  end
end
