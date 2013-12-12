# The time a 3rd-party shipping provider takes to respond to a request varies greatly.
# This class simulates these unpredictable delays in shipping rate retrieval so that
# load-testing tools run into situations that more accurately reflect the real world.

module ActiveMerchant
  module Shipping
    class BenchmarkCarrier < Carrier
      cattr_reader :name
      @@name = "Benchmark Carrier"
      
      DELAY_MAX = 30

      def find_rates(origin, destination, packages, options = {})
        sleep Random.rand * DELAY_MAX
        origin = Location.from(origin)
        destination = Location.from(destination)
        packages = Array(packages)
      end
      
    end
  end
end
