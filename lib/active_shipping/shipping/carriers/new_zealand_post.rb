module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

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

    end
  end
end
