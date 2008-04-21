require File.dirname(__FILE__) + '/../test_helper'

class UPSTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages = ActiveMerchant::Shipping::TestFixtures.packages.dup
    @locations = ActiveMerchant::Shipping::TestFixtures.locations.dup
    @carrier = UPS.new(fixtures(:ups))
  end
  
  def test_us_to_uk
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(  @locations[:beverly_hills],
                                  @locations[:london],
                                  @packages.values_at(:big_half_pound),
                                  :test => true)
    end
  end
  
  def test_just_country_given
    response = @carrier.find_rates( @locations[:beverly_hills],
                                    Location.new(:country => 'CA'),
                                    Package.new(100, [5,10,20]))
    assert_not_equal [], response.rates
  end
  
  def test_ottawa_to_beverly_hills
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(  @locations[:ottawa],
                                  @locations[:beverly_hills],
                                  @packages.values_at(:book, :wii),
                                  :test => true)
    end
    
    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates
    
    rate = response.rates.first
    assert_equal 'UPS', rate.carrier
    assert_equal 'CAD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :wii), rate.packages
    
    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end
  
  def test_bare_packages
    response = nil
    p = Package.new(0,0)
    assert_nothing_raised do
      response = @carrier.find_rates( @locations[:beverly_hills], # imperial (U.S. origin)
                                  @locations[:ottawa],
                                  p, :test => true)
    end
    assert response.success?, response.message
    assert_nothing_raised do
      response = @carrier.find_rates( @locations[:ottawa],
                                  @locations[:beverly_hills], # metric
                                  p, :test => true)
    end
    assert response.success?, response.message
  end
end