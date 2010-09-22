require 'test_helper'

class PackageTest < Test::Unit::TestCase
 
  GRAMS_IN_AN_OUNCE = 28.349523125
  OUNCES_IN_A_GRAM = 0.0352739619495804
  INCHES_IN_A_CM = 0.393700787401575
  CM_IN_AN_INCH = 2.54
  
  def setup
    @imperial_package = Package.new(65, [3,6,8.5],
                          :units => :imperial,
                          :value => 10.65,
                          :currency => 'USD'
                        )
                                        
    @metric_package = Package.new(100, [5,18.5,40],
                        :value => 860,
                        :currency => 'CAD'
                      )
    
    @packages = TestFixtures.packages
  end
  
  def test_accessors
    # :wii => Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial, :value => 269.99, :currency => 'GBP')
    wii = @packages[:wii]
    [:x, :max, :long, :length].each do |sym|
      assert_equal 15, wii.inches(sym)
      assert_equal 15, wii.in(sym)
      assert_equal 15 * CM_IN_AN_INCH, wii.centimetres(sym)
      assert_equal 15 * CM_IN_AN_INCH, wii.cm(sym)
    end
    [:y, :mid, :width, :wide].each do |sym|
      assert_equal 10, wii.inches(sym)
      assert_equal 10, wii.in(sym)
      assert_equal 10 * CM_IN_AN_INCH, wii.centimetres(sym)
      assert_equal 10 * CM_IN_AN_INCH, wii.cm(sym)
    end
    [:z, :min, :height, :high, :depth, :deep].each do |sym|
      assert_equal 4.5, wii.inches(sym)
      assert_equal 4.5, wii.in(sym)
      assert_equal 4.5 * CM_IN_AN_INCH, wii.centimetres(sym)
      assert_equal 4.5 * CM_IN_AN_INCH, wii.cm(sym)
    end
    [:pounds, :lbs, :lb].each do |sym|
      assert_equal 7.5, wii.send(sym)
    end
    [:ounces, :oz].each do |sym|
      assert_equal 120, wii.send(sym)
    end
    [:grams, :g].each do |sym|
      assert_equal 120 * GRAMS_IN_AN_OUNCE, wii.send(sym)
    end
    [:kilograms, :kgs, :kg].each do |sym|
      assert_equal 120 * GRAMS_IN_AN_OUNCE / 1000, wii.send(sym)
    end
    assert_equal 675.0, wii.inches(:volume)
    assert_equal 675.0, wii.inches(:box_volume)
    
    
    assert_equal 'GBP', wii.currency
    assert_equal 26999, wii.value
  end

  def test_package_from_mass
    pkg = Package.new(Quantified::Mass.new(10, :pounds), [])
    assert_equal 10, pkg.weight
  end
end