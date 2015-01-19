module ActiveShipping
  class Kunaki < Carrier
    self.retry_safe = true

    cattr_reader :name
    @@name = "Kunaki"

    URL = 'https://Kunaki.com/XMLService.ASP'

    CARRIERS = ["UPS", "USPS", "FedEx", "Royal Mail", "Parcelforce", "Pharos", "Eurotrux", "Canada Post", "DHL"]

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
      country = COUNTRIES[destination.country_code]
      state_province = %w(US CA).include?(destination.country_code.to_s) ? destination.state : ''

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.ShippingOptions do
          xml.AddressInfo do
            xml.Country(country)
            xml.State_Province(state_province)
            xml.PostalCode(destination.zip)
          end

          options[:items].each do |item|
            xml.Product do
              xml.ProductId(item[:sku])
              xml.Quantity(item[:quantity])
            end
          end
        end
      end
      builder.to_xml
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
      CARRIERS.dup.find { |carrier| service.to_s =~ /^#{carrier}/i } || service.to_s.split(" ").first
    end

    def parse(xml)
      response = {}
      response["Options"] = []

      document = Nokogiri.XML(sanitize(xml))

      response["ErrorCode"] = document.at('/Response/ErrorCode').text
      response["ErrorText"] = document.at('/Response/ErrorText').text

      document.xpath("Response/Option").each do |node|
        rate = {}
        rate["Description"] = node.at("Description").text
        rate["Price"]       = node.at("Price").text
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

    def success?(response)
      response["ErrorCode"] == "0"
    end

    def message_from(response)
      response["ErrorText"]
    end
  end
end
