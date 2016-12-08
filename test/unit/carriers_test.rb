require 'test_helper'

class CarriersTest < ActiveSupport::TestCase

  def test_get_usps_by_string
    assert_equal ActiveShipping::USPS, ActiveShipping::Carriers.find('usps')
    assert_equal ActiveShipping::USPS, ActiveShipping::Carriers.find('USPS')
  end

  def test_get_usps_by_name
    assert_equal ActiveShipping::USPS, ActiveShipping::Carriers.find(:usps)
  end

  def test_get_unknown_carrier
    assert_raises(NameError) { ActiveShipping::Carriers.find(:polar_north) }
  end
end
