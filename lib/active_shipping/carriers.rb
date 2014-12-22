require 'active_shipping/carriers/benchmark_carrier'
require 'active_shipping/carriers/bogus_carrier'
require 'active_shipping/carriers/ups'
require 'active_shipping/carriers/usps'
require 'active_shipping/carriers/fedex'
require 'active_shipping/carriers/shipwire'
require 'active_shipping/carriers/kunaki'
require 'active_shipping/carriers/canada_post'
require 'active_shipping/carriers/new_zealand_post'
require 'active_shipping/carriers/canada_post_pws'
require 'active_shipping/carriers/stamps'

module ActiveShipping
  module Carriers
    class <<self
      def all
        [BenchmarkCarrier, BogusCarrier, USPS, FedEx, Shipwire, Kunaki, CanadaPost, NewZealandPost, CanadaPostPWS, Stamps]
      end
    end
  end
end
