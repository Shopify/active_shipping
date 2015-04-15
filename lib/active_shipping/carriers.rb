module ActiveShipping
  module Carriers
    extend self

    attr_reader :registered
    @registered = []

    def register(class_name, autoload_require)
      ActiveShipping.autoload(class_name, autoload_require)
      self.registered << class_name
    end

    def all
      ActiveShipping::Carriers.registered.map { |name| ActiveShipping.const_get(name) }
    end

    def find(name)
      all.find { |c| c.name.downcase == name.to_s.downcase } or raise NameError, "unknown carrier #{name}"
    end
  end
end

ActiveShipping::Carriers.register :BenchmarkCarrier, 'active_shipping/carriers/benchmark_carrier'
ActiveShipping::Carriers.register :BogusCarrier,     'active_shipping/carriers/bogus_carrier'
ActiveShipping::Carriers.register :UPS,              'active_shipping/carriers/ups'
ActiveShipping::Carriers.register :USPS,             'active_shipping/carriers/usps'
ActiveShipping::Carriers.register :FedEx,            'active_shipping/carriers/fedex'
ActiveShipping::Carriers.register :Shipwire,         'active_shipping/carriers/shipwire'
ActiveShipping::Carriers.register :Kunaki,           'active_shipping/carriers/kunaki'
ActiveShipping::Carriers.register :CanadaPost,       'active_shipping/carriers/canada_post'
ActiveShipping::Carriers.register :NewZealandPost,   'active_shipping/carriers/new_zealand_post'
ActiveShipping::Carriers.register :CanadaPostPWS,    'active_shipping/carriers/canada_post_pws'
ActiveShipping::Carriers.register :Stamps,           'active_shipping/carriers/stamps'
ActiveShipping::Carriers.register :Correios,         'active_shipping/carriers/correios'
