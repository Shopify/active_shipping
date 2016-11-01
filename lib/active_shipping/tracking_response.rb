module ActiveShipping

  # Represents the response to a {ActiveShipping::Carrier#find_tracking_info} call.
  #
  # @note Some carriers provide more information that others, so not all attributes
  #   will be set, depending on what carrier you are using.
  #
  # @!attribute carrier
  #   @return [Symbol]
  #
  # @!attribute carrier_name
  #   @return [String]
  #
  # @!attribute status
  #   @return [Symbol]
  #
  # @!attribute status_code
  #   @return [string]
  #
  # @!attribute status_description
  #   @return [String]
  #
  # @!attribute ship_time
  #   @return [Date, Time]
  #
  # @!attribute scheduled_delivery_date
  #   @return [Date, Time]
  #
  # @!attribute actual_delivery_date
  #   @return [Date, Time]
  #
  # @!attribute attempted_delivery_date
  #   @return [Date, Time]
  #
  # @!attribute delivery_signature
  #   @return [String]
  #
  # @!attribute tracking_number
  #   @return [String]
  #
  # @!attribute shipment_events
  #   @return [Array<ActiveShipping::ShipmentEvent>]
  #
  # @!attribute shipper_address
  #   @return [ActiveShipping::Location]
  #
  # @!attribute origin
  #   @return [ActiveShipping::Location]
  #
  # @!attribute destination
  #   @return [ActiveShipping::Location]
  class TrackingResponse < Response
    attr_reader :carrier,:carrier_name,
                :status,:status_code, :status_description,
                :ship_time, :scheduled_delivery_date, :actual_delivery_date, :attempted_delivery_date,
                :delivery_signature, :tracking_number, :shipment_events,
                :shipper_address, :origin, :destination

    # @params (see ActiveShipping::Response#initialize)
    def initialize(success, message, params = {}, options = {})
      @carrier = options[:carrier].parameterize.to_sym
      @carrier_name = options[:carrier]
      @status = options[:status]
      @status_code = options[:status_code]
      @status_description = options[:status_description]
      @ship_time = options[:ship_time]
      @scheduled_delivery_date = options[:scheduled_delivery_date]
      @actual_delivery_date = options[:actual_delivery_date]
      @attempted_delivery_date = options[:attempted_delivery_date]
      @delivery_signature = options[:delivery_signature]
      @tracking_number = options[:tracking_number]
      @shipment_events = Array(options[:shipment_events])
      @shipper_address = options[:shipper_address]
      @origin = options[:origin]
      @destination = options[:destination]
      super
    end

    # The latest tracking event for this shipment, i.e. the current status.
    # @return [ActiveShipping::ShipmentEvent]
    def latest_event
      @shipment_events.last
    end

    # Returns `true` if the shipment has arrived at the destination.
    # @return [Boolean]
    def is_delivered?
      @status == :delivered
    end

    # Returns `true` if something out of the ordinary has happened during
    # the delivery of this package.
    # @return [Boolean]
    def has_exception?
      @status == :exception
    end

    alias_method :exception_event, :latest_event
    alias_method :delivered?, :is_delivered?
    alias_method :exception?, :has_exception?
    alias_method :scheduled_delivery_time, :scheduled_delivery_date
    alias_method :actual_delivery_time, :actual_delivery_date
    alias_method :attempted_delivery_time, :attempted_delivery_date

    def ==(other)
      attributes = %i(carrier carrier_name status status_code status_description ship_time scheduled_delivery_date
        actual_delivery_date attempted_delivery_date delivery_signature tracking_number shipper_address
        origin destination
      )

      attributes.all? { |attr| self.public_send(attr) == other.public_send(attr) } && compare_shipment_events(other)
    end

    private
    # Ensure order doesn't matter when comparing shipment_events
    def compare_shipment_events(other)
      shipment_events.sort_by(&:time) == other.shipment_events.sort_by(&:time)
    end
  end
end
