require File.dirname(__FILE__) + '/../test_helper'

class UPSTest < Test::Unit::TestCase
  
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = UPS.new(fixtures(:ups))
  end
  
  def test_tracking
    assert_nothing_raised do
      response = @carrier.find_tracking_info('1Z5FX0076803466397')
    end
  end
  
  def test_tracking_with_bad_number
    assert_raises ResponseError do
      response = @carrier.find_tracking_info('1Z12345')
    end
  end
  
  def test_tracking_with_another_number
    assert_nothing_raised do
      response = @carrier.find_tracking_info('1Z67Y4260390005815')
    end
  end
  
  def test_us_to_uk
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:london],
                   @packages.values_at(:big_half_pound),
                   :test => true
                 )
    end
  end
  
  def test_puerto_rico
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   Location.new(:city => 'Ponce', :country => 'US', :state => 'PR', :zip => '00733-1283'),
                   @packages.values_at(:big_half_pound),
                   :test => true
                 )
    end
  end
  
  def test_just_country_given
    response = @carrier.find_rates( 
                 @locations[:beverly_hills],
                 Location.new(:country => 'CA'),
                 Package.new(100, [5,10,20])
               )
    assert_not_equal [], response.rates
  end
  
  def test_ottawa_to_beverly_hills
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills],
                   @packages.values_at(:book, :wii),
                   :test => true
                 )
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
  
  def test_ottawa_to_us_fails_without_zip
    assert_raises ResponseError do
      @carrier.find_rates(
        @locations[:ottawa],
        Location.new(:country => 'US'),
        @packages.values_at(:book, :wii),
        :test => true
      )
    end
  end
  
  def test_ottawa_to_us_succeeds_with_only_zip
    assert_nothing_raised do
      @carrier.find_rates(
        @locations[:ottawa],
        Location.new(:country => 'US', :zip => 90210),
        @packages.values_at(:book, :wii),
        :test => true
      )
    end
  end
  
  def test_us_to_uk_with_different_pickup_types
    assert_nothing_raised do
      daily_response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:london],
        @packages.values_at(:book, :wii),
        :pickup_type => :daily_pickup,
        :test => true
      )
      one_time_response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:london],
        @packages.values_at(:book, :wii),
        :pickup_type => :one_time_pickup,
        :test => true
      )
      assert_not_equal daily_response.rates.map(&:price), one_time_response.rates.map(&:price)
    end
  end
  
  def test_bare_packages
    response = nil
    p = Package.new(0,0)
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills], # imperial (U.S. origin)
                   @locations[:ottawa],
                   p,
                   :test => true
                 )
    end
    assert response.success?, response.message
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills], # metric
                   p,
                   :test => true
                 )
    end
    assert response.success?, response.message
  end
  
  def test_different_rates_for_residential_and_commercial_destinations
    responses = {}
    locations = [
      :real_home_as_residential, :real_home_as_commercial,
      :fake_home_as_residential, :fake_home_as_commercial,
      :real_google_as_residential, :real_google_as_commercial,
      :fake_google_as_residential, :fake_google_as_commercial
      ]
      
    locations.each do |location|
      responses[location] = @carrier.find_rates(
                              @locations[:beverly_hills],
                              @locations[location],
                              @packages.values_at(:chocolate_stuff)
                            )
    end
    
    prices_of = lambda {|sym| responses[sym].rates.map(&:price)}
    
    # this is how UPS does things...
    # if it's a real residential address and UPS knows it, then they return
    # residential rates whether or not we have the ResidentialAddressIndicator:
    assert_equal prices_of.call(:real_home_as_residential), prices_of.call(:real_home_as_commercial)
    
    # if UPS doesn't know about the address, and we HAVE the ResidentialAddressIndicator,
    # then UPS will default to residential rates:
    assert_equal prices_of.call(:real_home_as_residential), prices_of.call(:fake_home_as_residential)
    
    # if UPS doesn't know about the address, and we DON'T have the ResidentialAddressIndicator,
    # then UPS will default to commercial rates:
    assert_not_equal prices_of.call(:fake_home_as_residential), prices_of.call(:fake_home_as_commercial)
    assert prices_of.call(:fake_home_as_residential).first > prices_of.call(:fake_home_as_commercial).first
    
    
    # if it's a real commercial address and UPS knows it, then they return
    # commercial rates whether or not we have the ResidentialAddressIndicator:
    assert_equal prices_of.call(:real_google_as_commercial), prices_of.call(:real_google_as_residential)
    
    # if UPS doesn't know about the address, and we DON'T have the ResidentialAddressIndicator,
    # then UPS will default to commercial rates:
    assert_equal prices_of.call(:real_google_as_commercial), prices_of.call(:fake_google_as_commercial)
    
    # if UPS doesn't know about the address, and we HAVE the ResidentialAddressIndicator,
    # then UPS will default to residential rates:
    assert_not_equal prices_of.call(:fake_google_as_commercial), prices_of.call(:fake_google_as_residential)
    assert prices_of.call(:fake_home_as_residential).first > prices_of.call(:fake_home_as_commercial).first
  end
end