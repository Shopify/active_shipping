module ActiveMerchant
  module Shipping
    class FedEx < Carrier
      cattr_reader :name
      @@name = "FedEx"
      
      
      def find_rates(origin, destination, packages, options = {})
        origin = Location.from(origin)
        destination = Location.from(destination)
        packages = Array(packages)
      end
      
    end
  end
end
