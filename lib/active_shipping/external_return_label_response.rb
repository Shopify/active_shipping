module ActiveShipping #:nodoc:

  class ExternalReturnLabelResponse < Response
    attr_reader :carrier # symbol
    attr_reader :carrier_name # string
    attr_reader :tracking_number # string
    attr_reader :return_label # string
    attr_reader :postal_routing # string

    def initialize(success, message, params = {}, options = {})
      @carrier = options[:carrier].parameterize.to_sym
      @carrier_name = options[:carrier]
      @return_label = options[:return_label]
      @tracking_number = options[:tracking_number]
      @postal_routing = options[:postal_routing]
      super
    end

    def has_exception?
      @status == :exception
    end

    alias_method(:exception?, :has_exception?)
  end

end
