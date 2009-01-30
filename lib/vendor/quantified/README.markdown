Quantified
==========

Pretty quantifiable measurements which feel like ActiveSupport::Duration.

Access whichever included attributes you want like so:

    require 'quantified/mass'
    require 'quantified/length'

Add methods to Numeric (only plural, must correspond with plural unit names):

    Mass.numeric_methods :grams, :kilograms, :ounces, :pounds
    Length.numeric_methods :metres, :centimetres, :inches, :feet

Then you can do things like this:

    1.feet == 12.inches
    # => true
    
    18.inches.to_feet
    # => #<Quantified::Length: 1.5 feet>
    
    (2.5).feet.in_millimetres.to_s
    # => "762.0 millimetres"


You can easily define new attributes. Here's length.rb:

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
          one :inch, :is => Length.new(2.540, :centimetres)
      
          one :foot, :plural => :feet, :is => Length.new(12, :inches)
          one :yard, :is => Length.new(3, :feet)
          one :mile, :is => Length.new(5280, :feet)
        end
      end
    end
