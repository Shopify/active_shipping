require 'ruby-debug'

module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

      class NewZealandPostRateResponse < RateResponse
      end

      URL = "http://workshop.nzpost.co.nz/api/v1/rate.xml"

      # Override to return required keys in options hash for initialize method.
      def requirements
        [:api_key]
      end

      # Override with whatever you need to get the rates
      def find_rates(origin, destination, packages, options = {})

      end

      def maximum_weight
        Mass.new(20, :kilograms)
      end

      protected

      def node_text_or_nil(xml_node)
        xml_node ? xml_node.text : nil
      end

      # Override in subclasses for non-U.S.-based carriers.
      def self.default_location
        Location.new( :country => 'NZ',
                      :city => 'Wellington',
                      :address1 => '455 Rexford Dr',
                      :zip => '6012',
                      :phone => '')
      end

      private

      def build_rectangular_request_params(origin, destination, line_items = [], options = {})
        params = {
          :postcode_src => origin[:postal_code],
          :postcode_dest => destination[:postal_code],
          :api_key => @options[:api_key]
        }

        combine_line_items(line_items).merge(params)
      end

      def combine_line_items(line_items)
        {
          :height => line_items.first.centimetres(:height).to_s,
          :thickness => line_items.first.centimetres(:width).to_s,
          :length => line_items.first.centimetres(:length).to_s,
          :weight =>"%.1f" % (line_items.first.weight.amount / 1000.0)
        }
      end

      def parse_rate_response(origin, destination, packages, response, options={})
        # xml = REXML::Document.new(response)
        # if success = response_success?(xml)
        #   rate_estimates = []
        #   xml.elements.each('hash/products-by-service') do ||
        #   end
        # end
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
