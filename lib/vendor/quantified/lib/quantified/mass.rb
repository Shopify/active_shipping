module Quantified
  class Mass < Attribute
    system :metric do
      primitive :gram
      
      one :milligram, :is => Mass.new(0.001, :grams)
      one :kilogram, :is => Mass.new(1000, :grams)
    end
    
    system :imperial do
      primitive :ounce
      one :ounce, :is => Mass.new(28.349523125, :grams)
      
      one :pound, :is => Mass.new(16, :ounces)
      one :stone, :is => Mass.new(14, :pounds)
      one :short_ton, :is => Mass.new(2000, :pounds)
    end
  end
end