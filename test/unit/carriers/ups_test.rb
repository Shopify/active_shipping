require File.dirname(__FILE__) + '/../../test_helper'

class UPSTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages               = fixtures(:packages)
    @locations              = fixtures(:locations)
    @carrier                = UPS.new(
                                :key => 'key',
                                :login => 'login',
                                :password => 'password'
                              )
  end
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do UPS.new end
    assert_raises ArgumentError do UPS.new(:login => 'blah', :password => 'bloo') end
    assert_raises ArgumentError do UPS.new(:login => 'blah', :key => 'kee') end
    assert_raises ArgumentError do UPS.new(:password => 'bloo', :key => 'kee') end
    assert_nothing_raised { UPS.new(:login => 'blah', :password => 'bloo', :key => 'kee')}
  end
end