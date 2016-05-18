module ActiveShipping
  class ShipmentEvent
    attr_reader :name, :time, :location, :message, :type_code

    def initialize(name, time, location, message = nil, type_code = nil)
      @name, @time, @location, @message, @type_code = name, time, location, message, type_code
    end

    def delivered?
      status == :delivered
    end

    def status
      @status ||= name.downcase.gsub("\s", "_").to_sym
    end

    def ==(other)
      attributes = %i(name time location message type_code)
      attributes.all? { |attr| self.public_send(attr) == other.public_send(attr) }
    end
  end
end
