module Quantified
  class Length < Attribute
    system :metric do
      primitive :metre

      one :centimetre, :is => Length.new(0.01, :metres)
      one :millimetre, :is => Length.new(0.1, :centimetres)
      one :kilometre, :is => Length.new(1000, :metres)
    end

    system :imperial do
      primitive :inch
      one :inch, :is => Length.new(0.0254, :metres)

      one :foot, :plural => :feet, :is => Length.new(12, :inches)
      one :yard, :is => Length.new(3, :feet)
      one :mile, :is => Length.new(5280, :feet)
    end
  end
end
