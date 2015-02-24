module ActiveShipping
  class DeliveryDateEstimatesResponse < Response
    attr_reader :delivery_estimates

    def initialize(success, message, params = {}, options = {})
      @delivery_estimates = Array(options[:delivery_estimates])
      super
    end

  end
end
