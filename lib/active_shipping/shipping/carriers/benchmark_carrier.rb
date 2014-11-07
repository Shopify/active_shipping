# The time a 3rd-party shipping provider takes to respond to a request varies greatly.
# This class simulates these unpredictable delays in shipping rate retrieval so that
# load-testing tools run into situations that more accurately reflect the real world.

module ActiveMerchant
  module Shipping
    class BenchmarkCarrier < Carrier
      cattr_reader :name
      @@name = "Benchmark Carrier"

      def find_rates(origin, destination, packages, options = {})
        origin = Location.from(origin)
        destination = Location.from(destination)
        packages = Array(packages)

        delay_time = generate_simulated_lag

        bogus_estimate = RateEstimate.new(
          origin, destination, @@name,
          "Free Benchmark Shipping", :total_price => 0, :currency => 'USD',
                                     :packages => packages, :delivery_range => [Time.now.utc.strftime("%Y-%d-%m"), Time.now.utc.strftime("%Y-%d-%m")]
          )
        RateResponse.new(true, "Success (delayed #{delay_time} seconds)", {:rate => 'free'}, :rates => [bogus_estimate], :xml => "<rate>free</rate>")
      end

      private

      def generate_simulated_lag(max_delay = 30)
        sleep Random.rand * max_delay
      end
    end
  end
end
