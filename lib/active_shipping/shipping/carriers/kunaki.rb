require 'builder'

module ActiveMerchant
  module Shipping
    class Kunaki < Carrier
      self.retry_safe = true
      
      cattr_reader :name
      @@name = "Kunaki"
      
      URL = 'https://Kunaki.com/XMLService.ASP'
                   
      CARRIERS = [ "UPS", "USPS", "FedEx", "Royal Mail", "Parcelforce", "Pharos", "Eurotrux", "Canada Post", "DHL" ]
      
      COUNTRIES = {
        'AR' => 'Argentina',
        'AU' => 'Australia',
        'AT' => 'Austria',
        'BE' => 'Belgium',
        'BR' => 'Brazil',
        'BG' => 'Bulgaria',
        'CA' => 'Canada',
        'CN' => 'China',
        'CY' => 'Cyprus',
        'CZ' => 'Czech Republic',
        'DK' => 'Denmark',
        'EE' => 'Estonia',
        'FI' => 'Finland',
        'FR' => 'France',
        'DE' => 'Germany',
        'GI' => 'Gibraltar',
        'GR' => 'Greece',
        'GL' => 'Greenland',
        'HK' => 'Hong Kong',
        'HU' => 'Hungary',
        'IS' => 'Iceland',
        'IE' => 'Ireland',
        'IL' => 'Israel',
        'IT' => 'Italy',
        'JP' => 'Japan',
        'LV' => 'Latvia',
        'LI' => 'Liechtenstein',
        'LT' => 'Lithuania',
        'LU' => 'Luxembourg',
        'MX' => 'Mexico',
        'NL' => 'Netherlands',
        'NZ' => 'New Zealand',
        'NO' => 'Norway',
        'PL' => 'Poland',
        'PT' => 'Portugal',
        'RO' => 'Romania',
        'RU' => 'Russia',
        'SG' => 'Singapore',
        'SK' => 'Slovakia',
        'SI' => 'Slovenia',
        'ES' => 'Spain',
        'SE' => 'Sweden',
        'CH' => 'Switzerland',
        'TW' => 'Taiwan',
        'TR' => 'Turkey',
        'UA' => 'Ukraine',
        'GB' => 'United Kingdom',
        'US' => 'United States',
        'VA' => 'Vatican City',
        'RS' => 'Yugoslavia',
        'ME' => 'Yugoslavia'
      }
                        
      def find_rates(origin, destination, packages, options = {})
        requires!(options, :items)
        commit(origin, destination, options)
      end
      
      def valid_credentials?
        true
      end
      
      private      
      def build_request(destination, options)
        xml = Builder::XmlMarkup.new
        xml.instruct!
        xml.tag! 'ShippingOptions' do
          xml.tag! 'AddressInfo' do
            xml.tag! 'Country', COUNTRIES[destination.country_code]
            
            state = ['US', 'CA'].include?(destination.country_code.to_s) ? destination.state : ''
            
            xml.tag! 'State_Province', state
            xml.tag! 'PostalCode', destination.zip
          end
        
          options[:items].each do |item|
            xml.tag! 'Product' do
              xml.tag! 'ProductId', item[:sku]
              xml.tag! 'Quantity', item[:quantity]
            end
          end
        end
        xml.target!
      end
      
      def commit(origin, destination, options)
        request = build_request(destination, options)
                
        response = parse( ssl_post(URL, request, "Content-Type" => "text/xml") )
        
        RateResponse.new(success?(response), message_from(response), response, 
          :rates => build_rate_estimates(response, origin, destination)
        )
      end
      
      def build_rate_estimates(response, origin, destination)
        response["Options"].collect do |quote|
          RateEstimate.new(origin, destination, carrier_for(quote["Description"]), quote["Description"],
            :total_price  => quote["Price"],
            :currency     => "USD"
          )
        end
      end
      
      def carrier_for(service)
        CARRIERS.dup.find{ |carrier| service.to_s =~ /^#{carrier}/i } || service.to_s.split(" ").first
      end
      
      def parse(xml)
        response = {}
        response["Options"] = []
        
        document = REXML::Document.new(sanitize(xml))
        
        response["ErrorCode"] = parse_child_text(document.root, "ErrorCode")
        response["ErrorText"] = parse_child_text(document.root, "ErrorText")
             
        document.root.elements.each("Option") do |e|
          rate = {}
          rate["Description"] = parse_child_text(e, "Description")
          rate["Price"]       = parse_child_text(e, "Price")
          response["Options"] << rate
        end
        response
      end
      
      def sanitize(response)
        result = response.to_s
        result.gsub!("\r\n", "")
        result.gsub!(/<(\/)?(BODY|HTML)>/, '')
        result
      end
      
      def parse_child_text(parent, name)
        if element = parent.elements[name]
          element.text
        end
      end
      
      def success?(response)
        response["ErrorCode"] == "0"
      end
      
      def message_from(response)
        response["ErrorText"]
      end
    end
  end
end