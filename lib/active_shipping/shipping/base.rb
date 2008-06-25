module ActiveMerchant
  module Shipping
    module Base
      mattr_accessor :mode
      self.mode = :production
      
      ALLCAPS_NAMES = ['usps','dhl'] # is the class name allcaps like USPS or camelcase like FedEx?
      
      def self.carrier(name)
        name = name.to_s.downcase
        ActiveMerchant::Shipping.const_get(ALLCAPS_NAMES.include?(name) ? name.upcase : name.camelize)
      end
    end
  end
end
