module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

      # class NewZealandPostRateResponse < RateResponse
      # end
      
      cattr_reader :name
      @@name = "New Zealand Post"

      URL = "http://workshop.nzpost.co.nz/api/v1/rate.xml"

      # Override to return required keys in options hash for initialize method.
      def requirements
        [:key]
      end

      # Override with whatever you need to get the rates
      def find_rates(origin, destination, packages, options = {})
        packages = Array(packages)
        rate_responses = []
        packages.each do |package|
          if package.tube?
            request_hash = build_tube_request_params(origin, destination, package, options)
          else
            request_hash = build_rectangular_request_params(origin, destination, package, options)
          end
          url = URL + '?' + request_hash.to_param
          response = ssl_get(url)
          rate_responses << parse_rate_response(origin, destination, package, response, options)
        end
        combine_rate_responses(rate_responses, packages)
      end

      def maximum_weight
        Mass.new(20, :kilograms)
      end

      protected

      # Override in subclasses for non-U.S.-based carriers.
      def self.default_location
        Location.new(:postal_code => '6011')
      end

      private

      def build_rectangular_request_params(origin, destination,  package, options = {})
        params = {
          :postcode_src => origin.postal_code,
          :postcode_dest => destination.postal_code,
          :api_key => @options[:key],
          :height => "#{package.centimetres(:height) * 10}",
          :thickness => "#{package.centimetres(:width) * 10}",
          :length => "#{package.centimetres(:length) * 10}",
          :weight =>"%.1f" % (package.weight.amount / 1000.0)
        }
      end

      def build_tube_request_params(origin, destination,  package, options = {})
        params = {
          :postcode_src => origin.postal_code,
          :postcode_dest => destination.postal_code,
          :api_key => @options[:key],
          :diameter => "#{package.centimetres(:width) * 10}",
          :length => "#{package.centimetres(:length) * 10}",
          :weight => "%.1f" % (package.weight.amount / 1000.0)
        }
      end

      def parse_rate_response(origin, destination, package, response, options={})
        xml = REXML::Document.new(response)
        if response_success?(xml)
          rate_estimates = []
          xml.elements.each('hash/products/product') do |prod|
            if( prod.get_text('packaging') == 'postage_only' )
              rate_estimates << RateEstimate.new(origin, 
                                                 destination,
                                                 @@name,
                                                 prod.get_text('service-group-description').to_s,
                                                 :total_price => prod.get_text('cost').to_s.to_f,
                                                 :currency => 'NZD',
                                                 :service_code => prod.get_text('code').to_s,
                                                 :package => package)
            end
          end
          
          RateResponse.new(true, "Success", Hash.from_xml(response), :rates => rate_estimates, :xml => response)
        else
          error_message = response_message(xml)
          RateResponse.new(false, error_message, Hash.from_xml(response), :rates => rate_estimates, :xml => response)
        end
      end

      def combine_rate_responses(rate_responses, packages)
        #if there are any failed responses, return on that response
        rate_responses.each do |r|
          return r if !r.success?
        end

        #group rate estimates by delivery type so that we can exclude any incomplete delviery types
        rate_estimate_delivery_types = {}
        rate_responses.each do |rr|
          rr.rate_estimates.each do |re|
            (rate_estimate_delivery_types[re.service_code] ||= []) << re
          end
        end
        rate_estimate_delivery_types.delete_if{ |type, re| re.size != packages.size }

        #combine cost estimates for remaining packages
        combined_rate_estimates = []
        rate_estimate_delivery_types.each do |type, re|
          total_price = re.sum(&:total_price)
          r = re.first
          combined_rate_estimates << RateEstimate.new(r.origin, r.destination, r.carrier,
                                                     r.service_name,
                                                     :total_price => total_price,
                                                     :currency => r.currency,
                                                     :service_code => r.service_code,
                                                     :packages => packages)
        end
        RateResponse.new(true, "Success", {}, :rates => combined_rate_estimates)
      end

      def response_success?(xml)
        xml.get_text('hash/status').to_s == 'success'
      end

      def response_message(xml)
        if response_success?(xml)
          'Success'
        else
          xml.get_text('hash/message').to_s
        end
      end

    end
  end
end
