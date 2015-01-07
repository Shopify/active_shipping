module ActiveShipping
  class ShippingResponse < Response
    attr_reader :shipping_id # string
    attr_reader :tracking_number # string

    def initialize(success, message, params = {}, options = {})
      @shipping_id = options[:shipping_id]
      @tracking_number = options[:tracking_number]
      super
    end
  end
end
