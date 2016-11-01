module ActiveShipping

  # Responce object class for calls to {ActiveShipping::Carrier#create_shipment}.
  #
  # @note Some carriers provide more information that others, so not all attributes
  #   will be set, depending on what carrier you are using.
  #
  # @!attribute shipping_id
  #   The unique identifier of the shipment, which can be used to further interact
  #   with the carrier's API.
  #   @return [String]
  #
  # @!attribute tracking_number
  #   The tracking number of the shipments, which can be shared with the customer and
  #   be used for {ActiveShipping::Carrier#find_tracking_info}.
  #   @return [String]
  class ShippingResponse < Response
    attr_reader :shipping_id, :tracking_number

    # Initializes a new ShippingResponse instance.
    #
    # @param success (see ActiveShipping::Response#initialize)
    # @param message (see ActiveShipping::Response#initialize)
    # @param params (see ActiveShipping::Response#initialize)
    # @option options (see ActiveShipping::Response#initialize)
    # @option options [String] :shipping_id Populates {#shipping_id}.
    # @option options [String] :tracking_number Populates {#tracking_number}.
    def initialize(success, message, params = {}, options = {})
      @shipping_id = options[:shipping_id]
      @tracking_number = options[:tracking_number]
      super
    end
  end
end
