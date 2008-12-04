require File.dirname(__FILE__) + '/../test_helper'

class FedExTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages               = fixtures(:packages)
    @locations              = fixtures(:locations)
    @carrier                = FedEx.new(fixtures(:fedex).merge(:test => true))
  end
  
  def test_just_country_given
    assert_nothing_raised do
      response = @carrier.find_rates( @locations[:beverly_hills],
                                      Location.new(:country => 'CZ'),
                                      Package.new(100, [5,10,20]))
    end
  end
  
  def test_us_to_canada
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(  @locations[:beverly_hills],
                                  @locations[:ottawa],
                                  @packages.values_at(:wii),
                                  :test => true)
      assert_not_equal [], response.rates
    end
  end
  
  def test_canada_to_us
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates( @locations[:ottawa],
                                  @locations[:beverly_hills],
                                  @packages.values_at(:wii),
                                  :test => true)
      assert_not_equal [], response.rates
    end
  end

end