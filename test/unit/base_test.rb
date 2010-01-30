require 'test_helper'

class BaseTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping

  def test_get_usps_by_string
    assert_equal USPS, Base.carrier('usps')
    assert_equal USPS, Base.carrier('USPS')
  end

  def test_get_usps_by_name
    assert_equal USPS, Base.carrier(:usps)
  end
  
  def test_get_unknown_carrier
    assert_raise(NameError){ Base.carrier(:polar_north) }
  end
end
