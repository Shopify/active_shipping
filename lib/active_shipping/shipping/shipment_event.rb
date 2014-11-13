module ActiveMerchant #:nodoc:
  module Shipping
    class ShipmentEvent
      attr_reader :name, :time, :location, :message

      def initialize(name, time, location, message = nil)
        @name, @time, @location, @message = name, time, location, message
      end

      def delivered?
        status == :delivered
      end

      def status
        @status ||= name.downcase.gsub("\s", "_").to_sym
      end
    end
  end
end
