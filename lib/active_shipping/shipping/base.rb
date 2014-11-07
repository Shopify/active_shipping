module ActiveMerchant
  module Shipping
    module Base
      mattr_accessor :mode
      self.mode = :production

      def self.carrier(name)
        ActiveMerchant::Shipping::Carriers.all.find { |c| c.name.downcase == name.to_s.downcase } ||
          raise(NameError, "unknown carrier #{name}")
      end
    end
  end
end
