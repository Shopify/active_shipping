require File.dirname(__FILE__) + '/../../test_helper'

class FedExTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do FedEx.new end
    assert_raises ArgumentError do FedEx.new(:account_number => '999999999') end
    assert_raises ArgumentError do FedEx.new(:meter_number => '7777777') end
  end
  
end