module ActiveShipping
  module Base
    mattr_accessor :mode
    self.mode = :production

    def self.carrier(name)
      ActiveShipping::Carriers.all.find { |c| c.name.downcase == name.to_s.downcase } ||
        raise(NameError, "unknown carrier #{name}")
    end
  end
end
