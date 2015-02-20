module ActiveShipping
  class DeliveryDateEstimate
    attr_reader :origin
    attr_reader :destination
    attr_reader :carrier
    attr_reader :service_name
    attr_reader :service_code
    attr_reader :date
    attr_reader :guaranteed

    def initialize(origin, destination, carrier, service_name, options={})
      @origin, @destination, @carrier, @service_name = origin, destination, carrier, service_name
      @service_code = options[:service_code]
      @date = options[:date]
      @guaranteed = options[:guaranteed]
    end
  end
end

