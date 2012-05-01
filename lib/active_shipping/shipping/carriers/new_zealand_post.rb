module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

      cattr_reader :name
      @@name = "New Zealand Post"

      URL = "http://api.nzpost.co.nz/ratefinder"

      def requirements
        [:key]
      end

      def find_rates(origin, destination, packages, options = {})
        options = @options.merge(options)
        request = RateRequest.from(origin, destination, packages, options)
        request.raw_responses = commit(request.urls) if request.new_zealand_origin?
        request.rate_response
      end

      protected

      def commit(urls)
        save_request(urls).map { |url| ssl_get(url) }
      end

      def self.default_location
        Location.new({
          :country => "NZ",
          :city => "Wellington",
          :address1 => "22 Waterloo Quay",
          :address2 => "Pipitea",
          :postal_code => "6011"
        })
      end

      class NewZealandPostRateResponse < RateResponse

        attr_reader :raw_responses

        def initialize(success, message, params = {}, options = {})
          @raw_responses = options[:raw_responses]
          super
        end
      end

      class RateRequest

        attr_reader :urls
        attr_writer :raw_responses

        def self.from(*args)
          return International.new(*args) unless domestic?(args[0..1])
          Domestic.new(*args)
        end

        def initialize(origin, destination, packages, options)
          @origin = Location.from(origin)
          @destination = Location.from(destination)
          @packages = Array(packages).map { |package| NewZealandPostPackage.new(package, api) }
          @params = { :format => "json", :api_key => options[:key] }
          @test = options[:test]
          @rates = @responses = @raw_responses = []
          @urls = @packages.map { |package| url(package) }
        end

        def rate_response
          @rates = rates
          NewZealandPostRateResponse.new(true, "success", response_params, response_options)
        rescue => error
          NewZealandPostRateResponse.new(false, error.message, response_params, response_options)
        end

        def new_zealand_origin?
          self.class.new_zealand?(@origin)
        end

        protected

        def self.new_zealand?(location)
          [ 'NZ', nil ].include?(Location.from(location).country_code)
        end

        def self.domestic?(locations)
          locations.select { |location| new_zealand?(location) }.size == 2
        end

        def response_options
          {
            :rates => @rates,
            :raw_responses => @raw_responses,
            :request => @urls,
            :test => @test
          }
        end

        def response_params
          { :responses => @responses }
        end

        def rate_options(products)
          {
            :total_price => products.sum { |product| price(product) },
            :currency => "NZD",
            :service_code => products.first["code"]
          }
        end

        def rates
          rates_hash.map do |service, products|
            RateEstimate.new(@origin, @destination, NewZealandPost.name, service, rate_options(products))
          end
        end

        def rates_hash
          products_hash.select { |service, products| products.size == @packages.size }
        end

        def products_hash
          product_arrays.flatten.group_by { |product| service_name(product) }
        end

        def product_arrays
          responses.map do |response|
            raise(response["message"]) unless response["status"] == "success"
            response["products"]
          end
        end

        def responses
          @responses = @raw_responses.map { |response| parse_response(response) }
        end

        def parse_response(response)
          JSON.parse(response)
        end

        def url(package)
          "#{URL}/#{api}?#{params(package).to_query}"
        end

        def params(package)
          @params.merge(api_params).merge(package.params)
        end

      end

      class Domestic < RateRequest
        def service_name(product)
          [ product["service_group_description"], product["description"] ].join(" ")
        end
        
        def api
          :domestic
        end

        def api_params
          {
            :postcode_src => @origin.postal_code,
            :postcode_dest => @destination.postal_code,
            :carrier => "all"
          }
        end

        def price(product)
          product["cost"].to_f
        end
      end

      class International < RateRequest

        def rates
          raise "New Zealand Post packages must originate in New Zealand" unless new_zealand_origin?
          super
        end

        def service_name(product)
          [ product["group"], product["name"] ].join(" ")
        end
        
        def api
          :international
        end

        def api_params
          { :country_code => @destination.country_code }
        end
        
        def price(product)
          product["price"].to_f
        end
      end

      class NewZealandPostPackage

        def initialize(package, api)
          @package = package
          @api = api
          @params = { :weight => weight, :length => length }
        end

        def params
          @params.merge(api_params).merge(shape_params)
        end

        protected

        def weight
          @package.kg
        end

        def length
          mm(:length)
        end

        def height
          mm(:height)
        end

        def width
          mm(:width)
        end

        def shape
          return :cylinder if @package.cylinder?
          :cuboid
        end

        def api_params
          send("#{@api}_params")
        end

        def international_params
          { :value => value }
        end

        def domestic_params
          {}
        end

        def shape_params
          send("#{shape}_params")
        end

        def cuboid_params
          { :height => height, :thickness => width }
        end

        def cylinder_params
          { :diameter => width }
        end

        def mm(measurement)
          @package.cm(measurement) * 10
        end

        def value
          return 0 unless @package.value && currency == "NZD"
          @package.value / 100
        end

        def currency
          @package.currency || "NZD"
        end

      end
    end
  end
end
