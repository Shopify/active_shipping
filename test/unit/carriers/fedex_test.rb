require File.dirname(__FILE__) + '/../../test_helper'

class FedExTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages               = fixtures(:packages)
    @locations              = fixtures(:locations)
    @carrier                = FedEx.new(
                                :login => 'login',
                                :password => 'password'
                              )
    @tracking_response = xml_fixture('fedex/domestic_shipment')
    @intl_tracking_response = xml_fixture('fedex/shipment_to_canada')
  end
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do FedEx.new end
    assert_raises ArgumentError do FedEx.new(:login => '999999999') end
    assert_raises ArgumentError do FedEx.new(:password => '7777777') end
    assert_nothing_raised { FedEx.new(:login => '999999999', :password => '7777777')}
  end
  
  def test_find_tracking_info_should_return_a_tracking_response
    FedEx.any_instance.expects(:commit).returns(@tracking_response)
    assert_equal 'ActiveMerchant::Shipping::TrackingResponse', @carrier.find_tracking_info('077973360390581').class.name
  end
  
  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    FedEx.any_instance.expects(:commit).returns(@intl_tracking_response)
    response = @carrier.find_tracking_info('931519441327', :carrier_code => 'fedex_express')
    assert_equal 14, response.shipment_events.size
  end
  
  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    FedEx.any_instance.expects(:commit).returns(@intl_tracking_response)
    response = @carrier.find_tracking_info('931519441327', :carrier_code => 'fedex_express')
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end
end