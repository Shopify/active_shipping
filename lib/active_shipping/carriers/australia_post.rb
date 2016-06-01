require 'active_support/core_ext/object/to_query'

module ActiveShipping
  class AustraliaPost < Carrier
    cattr_reader :name
    @@name = 'Australia Post'

    HOST = 'digitalapi.auspost.com.au'

    PARCEL_ENDPOINTS = {
      service: {
        domestic:      '/postage/parcel/domestic/service.json',
        international: '/postage/parcel/international/service.json'
      },
      calculate: {
        domestic:      '/postage/parcel/domestic/calculate.json',
        international: '/postage/parcel/international/calculate.json'
      }
    }.freeze

    def requirements
      [:api_key]
    end

    def find_rates(origin, destination, packages, options = {})
      packages = Array(packages)

      service_requests = packages.map do |package|
        service_request = ServiceRequest.new(origin, destination, package, options)

        service_request.parse(commit(service_request.url))
        service_request
      end

      combined_response = CombinedResponse.new(origin, destination, packages, service_requests)

      RateResponse.new(true, 'success', combined_response.params, combined_response.options)
    end

    def calculate_rates(origin, destination, packages, service_code, options = {})
      packages = Array(packages)

      calculate_requests = packages.map do |package|
        calculate_request = CalculateRequest.new(origin, destination, package, service_code, options)

        calculate_request.parse(commit(calculate_request.url))
        calculate_request
      end

      combined_response = CombinedResponse.new(origin, destination, packages, calculate_requests)

      RateResponse.new(true, 'success', combined_response.params, combined_response.options)
    end

    private

    def commit(request_url)
      ssl_get(request_url, headers)

    rescue ActiveUtils::ResponseError, ActiveShipping::ResponseError => e
      data          = JSON.parse(e.response.body)
      error_message = data['error'] && data['error']['errorMessage'] ? data['error']['errorMessage'] : 'unknown'

      RateResponse.new(false, error_message, data)
    end

    def headers
      {
        'Content-type' => 'application/json',
        'auth-key'     => @options[:api_key]
      }
    end

    class CombinedResponse

      def initialize(origin, destination, packages, requests)
        @requests    = requests
        @origin      = origin
        @destination = destination
        @packages    = packages
      end

      def options
        {
          rates:         rates,
          raw_responses: @requests.map(&:raw_response),
          request:       @requests.map(&:url)
        }
      end

      def params
        {
          responses: @requests.map(&:response)
        }
      end

      private

      def rate_options(rates)
        {
          service_name:       rates.first[:service_name],
          service_code:       rates.first[:service_code],
          total_price:        rates.sum { |rate| rate[:total_price] },
          currency:           'AUD',
          delivery_time_text: rates.first[:delivery_time_text]
        }
      end

      def rates
        rates = @requests.map(&:rates).flatten

        rates.group_by { |rate| rate[:service_name] }.map do |service_name, service_rates|
          next unless service_rates.size == @packages.size

          AustraliaPostRateEstimate.new(@origin, @destination, AustraliaPost.name, service_name, rate_options(service_rates))
        end.compact
      end

    end

    class AustraliaPostRequest
      attr_reader :raw_response
      attr_reader :response
      attr_reader :rates

      def initialize(origin, destination, package, options)
        @origin      = Location.from(origin)
        @destination = Location.from(destination)
        @package     = package
        @rates       = []
        @options     = options
      end

      def url
        endpoint = domestic_destination? ? @endpoints[:domestic] : @endpoints[:international]
        params   = domestic_destination? ? domestic_params : international_params

        URI::HTTPS.build(host: HOST, path: endpoint, query: params.to_query).to_s
      end

      def parse(data)
        @raw_response = data
        @response     = JSON.parse(data)
      end

      protected

      def domestic_destination?
        @destination.country_code == 'AU'
      end

      def domestic_params
        {
          length:        @package.cm(:length),
          width:         @package.cm(:width),
          height:        @package.cm(:height),
          weight:        @package.weight.in_kg.to_f.round(2),
          from_postcode: @origin.postal_code,
          to_postcode:   @destination.postal_code
        }
      end

      def international_params
        {
          weight:       @package.weight.in_kg.to_f.round(2),
          country_code: @destination.country_code
        }
      end

    end

    class ServiceRequest < AustraliaPostRequest

      def initialize(origin, destination, package, options)
        super
        @endpoints = PARCEL_ENDPOINTS[:service]
      end

      def parse(data)
        super

        @rates = response['services']['service'].map do |service|
          {
            service_name: service['name'],
            service_code: service['code'],
            total_price:  service['price'].to_f,
            currency:     'AUD'
          }
        end
      end

    end

    class CalculateRequest < AustraliaPostRequest
      attr_reader :service_code

      def initialize(origin, destination, package, service_code, options)
        super(origin, destination, package, options)

        @service_code = service_code
        @endpoints    = PARCEL_ENDPOINTS[:calculate]
      end

      def parse(data)
        super
        postage_result = response['postage_result']

        @rates = [{
          service_name:       postage_result['service'],
          service_code:       service_code,
          total_price:        postage_result['total_cost'].to_f,
          currency:           'AUD',
          delivery_time_text: postage_result['delivery_time']
        }]
      end

      private

      def calculate_params
        {
          service_code:   @service_code,
          option_code:    @options[:option_code],
          suboption_code: @options[:suboption_code],
          extra_cover:    @options[:extra_cover]
        }.
        # INFO: equivalent of .compact
        select { |_, value| !value.nil? }
      end

      def domestic_params
        super.merge(calculate_params)
      end

      def international_params
        super.merge(calculate_params)
      end

    end

    class AustraliaPostRateEstimate < RateEstimate
      attr_reader :delivery_time_text

      def initialize(origin, destination, carrier, service_name, options = {})
        super
        @delivery_time_text = options[:delivery_time_text]
      end

    end
  end
end
