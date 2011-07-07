module ActiveMerchant #:nodoc:
  module Shipping
    
    class TrackingResponse < Response
      attr_reader :carrier # symbol
      attr_reader :carrier_name # string
      attr_reader :delivered # boolean
      attr_reader :exception # boolean
      attr_reader :exception_event # hash of the offending ShipmentEvent
      attr_reader :status # hash of :code and :description
      attr_reader :tracking_number # string
      attr_reader :shipment_events # array of ShipmentEvents in chronological order
      attr_reader :origin, :destination
      
      def initialize(success, message, params = {}, options = {})
        @carrier = options[:carrier].parameterize.to_sym
        @carrier_name = options[:carrier]

        @delivered = options[:delivered]
        @exception, @exception_event = options[:exception], options[:exception_event]
        @status = options[:status]
        @tracking_number = options[:tracking_number]
        @shipment_events = Array(options[:shipment_events])
        @origin, @destination = options[:origin], options[:destination]
        super
      end

      def latest_event
        @shipment_events.last
      end

      def is_delivered?
        !!@delivered
      end

      def has_exception?
        !!@exception
      end

      alias_method(:delivered?, :is_delivered?)
      alias_method(:exception?, :has_exception?)

    end
    
  end
end