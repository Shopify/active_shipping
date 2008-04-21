require File.dirname(__FILE__) + '/../../test_helper'

class UPSTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages               = ActiveMerchant::Shipping::TestFixtures.packages.dup
    @locations              = ActiveMerchant::Shipping::TestFixtures.locations.dup
    @carrier                = UPS.new(fixtures(:ups))
  end
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do UPS.new end
    assert_raises ArgumentError do UPS.new(:login => 'blah', :password => 'bloo') end
    assert_raises ArgumentError do UPS.new(:login => 'blah', :key => 'kee') end
    assert_raises ArgumentError do UPS.new(:password => 'bloo', :key => 'kee') end
    assert_nothing_raised { UPS.new(:login => 'blah', :password => 'bloo', :key => 'kee')}
  end
end