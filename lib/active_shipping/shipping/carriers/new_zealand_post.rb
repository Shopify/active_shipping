require 'ruby-debug'

module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

      # class NewZealandPostRateResponse < RateResponse
      # end
      
      @@name = "NewZealandPost"

      URL = "http://workshop.nzpost.co.nz/api/v1/rate.xml"

      # Override to return required keys in options hash for initialize method.
      def requirements
        [:api_key]
      end

      # Override with whatever you need to get the rates
      def find_rates(origin, destination, packages, options = {})
        packages = Array(packages)
        request_hash = build_rectangular_request_params(origin, destination, packages, options)
        url = URL + '?' + request_hash.to_param
        xml_response = ssl_get(url)
        parse_rate_response(origin, destination, packages, xml_response, options)
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

      def build_rectangular_request_params(origin, destination, line_items = [], options = {})
        params = {
          :postcode_src => origin.postal_code,
          :postcode_dest => destination.postal_code,
          :api_key => @options[:api_key]
        }

        combine_line_items(line_items).merge(params)
      end

      def combine_line_items(line_items) 
        {
          :height => "#{line_items.first.centimetres(:height) * 10}",
          :thickness => "#{line_items.first.centimetres(:width) * 10}",
          :length => "#{line_items.first.centimetres(:length) * 10}",
          :weight =>"%.1f" % (line_items.first.weight.amount / 1000.0)
        }
      end

      def parse_rate_response(origin, destination, packages, response, options={})
        xml = REXML::Document.new(response)
        if response_success?(xml)
          rate_estimates = []
          xml.elements.each('hash/products/product') do |prod|
            rate_estimates << RateEstimate.new(origin, 
                                               destination,
                                               @@name,
                                               prod.get_text('service-group-description').to_s,
                                               :total_price => prod.get_text('cost').to_s.to_f,
                                               :currency => 'NZD',
                                               :service_code => prod.get_text('service').to_s,
                                               :packages => packages)
          end
          
          RateResponse.new(true, "Success", Hash.from_xml(response), :rates => rate_estimates, :xml => response)
        else
          error_message = response_message(xml)
          RateResponse.new(false, error_message, Hash.from_xml(response), :rates => rate_estimates, :xml => response)
        end
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
