require 'active_shipping/shipping/carriers/bogus_carrier'
require 'active_shipping/shipping/carriers/usps'
require 'active_shipping/shipping/carriers/fedex'
require 'active_shipping/shipping/carriers/shipwire'

module ActiveMerchant
  module Shipping
    module Carriers
      class <<self
        def all
          [BogusCarrier, USPS, FedEx, Shipwire]
        end
      end
    end
  end
end