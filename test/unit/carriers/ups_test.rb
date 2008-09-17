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
    @tracking_response = xml_fixture('ups/shipment_from_tiger_direct')
  end
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do UPS.new end
    assert_raises ArgumentError do UPS.new(:login => 'blah', :password => 'bloo') end
    assert_raises ArgumentError do UPS.new(:login => 'blah', :key => 'kee') end
    assert_raises ArgumentError do UPS.new(:password => 'bloo', :key => 'kee') end
    assert_nothing_raised { UPS.new(:login => 'blah', :password => 'bloo', :key => 'kee')}
  end
  
  def test_find_tracking_info_should_return_a_tracking_response
    UPS.any_instance.expects(:commit).returns(@tracking_response)
    assert_equal 'ActiveMerchant::Shipping::TrackingResponse', @carrier.find_tracking_info('1Z5FX0076803466397').class.name
  end
  
  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    UPS.any_instance.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 8, response.shipment_events.size
  end
  
  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    UPS.any_instance.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end
  
  def test_find_tracking_info_should_have_correct_names_for_shipment_events
    UPS.any_instance.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal [ "BILLING INFORMATION RECEIVED",
                   "IMPORT SCAN",
                   "LOCATION SCAN",
                   "LOCATION SCAN",
                   "DEPARTURE SCAN",
                   "ARRIVAL SCAN",
                   "OUT FOR DELIVERY",
                   "DELIVERED" ], response.shipment_events.map(&:name)
  end
  
  def test_add_origin_and_destination_data_to_shipment_events_where_appropriate
    UPS.any_instance.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal '175 AMBASSADOR', response.shipment_events.first.location.address1
    assert_equal 'K1N5X8', response.shipment_events.last.location.postal_code
  end
end