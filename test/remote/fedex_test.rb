require File.dirname(__FILE__) + '/../test_helper'

class FedExTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages               = TestFixtures.packages
    @locations              = TestFixtures.locations
    @carrier                = FedEx.new(fixtures(:fedex).merge(:test => true))
  end
  
  def test_us_to_canada
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(  @locations[:beverly_hills],
                                  @locations[:ottawa],
                                  @packages.values_at(:wii),
                                  :test => true)
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_canada_to_us
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates( @locations[:ottawa],
                                  @locations[:beverly_hills],
                                  @packages.values_at(:wii),
                                  :test => true)
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end
  
  def test_ottawa_to_beverly_hills
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(  @locations[:ottawa],
                                  @locations[:beverly_hills],
                                  @packages.values_at(:book, :wii),
                                  :test => true)
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_tracking
    assert_nothing_raised do
      @carrier.find_tracking_info('077973360403984')
    end
  end
  
end