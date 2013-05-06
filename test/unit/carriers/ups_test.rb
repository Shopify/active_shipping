require 'test_helper'

class UPSTest < Test::Unit::TestCase

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = UPS.new(
                   :key => 'key',
                   :login => 'login',
                   :password => 'password'
                 )
    @tracking_response = xml_fixture('ups/shipment_from_tiger_direct')

  end

  def test_initialize_options_requirements
    assert_raises(ArgumentError) { UPS.new }
    assert_raises(ArgumentError) { UPS.new(:login => 'blah', :password => 'bloo') }
    assert_raises(ArgumentError) { UPS.new(:login => 'blah', :key => 'kee') }
    assert_raises(ArgumentError) { UPS.new(:password => 'bloo', :key => 'kee') }
    assert_nothing_raised { UPS.new(:login => 'blah', :password => 'bloo', :key => 'kee') }
  end

  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'ActiveMerchant::Shipping::TrackingResponse', @carrier.find_tracking_info('1Z5FX0076803466397').class.name
  end

  def test_find_tracking_info_should_mark_shipment_as_delivered
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal true, @carrier.find_tracking_info('1Z5FX0076803466397').delivered?
  end

  def test_find_tracking_info_should_return_correct_carrier
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal :ups, @carrier.find_tracking_info('1Z5FX0076803466397').carrier
  end

  def test_find_tracking_info_should_return_correct_carrier_name
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'UPS', @carrier.find_tracking_info('1Z5FX0076803466397').carrier_name
  end

  def test_find_tracking_info_should_return_correct_status
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal :delivered, @carrier.find_tracking_info('1Z5FX0076803466397').status
  end

  def test_find_tracking_info_should_return_correct_status_code
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'd', @carrier.find_tracking_info('1Z5FX0076803466397').status_code.downcase
  end

  def test_find_tracking_info_should_return_correct_status_description
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'delivered', @carrier.find_tracking_info('1Z5FX0076803466397').status_description.downcase
  end

  def test_find_tracking_info_should_have_an_out_for_delivery_status
    out_for_delivery_tracking_response = xml_fixture('ups/out_for_delivery_shipment')
    @carrier.expects(:commit).returns(out_for_delivery_tracking_response)
    assert_equal :out_for_delivery, @carrier.find_tracking_info('1Z5FX0076803466397').status
  end

  def test_find_tracking_info_should_return_destination_address
    @carrier.expects(:commit).returns(@tracking_response)
    result = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 'ottawa', result.destination.city.downcase
    assert_equal 'ON', result.destination.state
  end

  def test_find_tracking_info_should_return_destination_address_for_abbreviated_response
    tracking_response = xml_fixture('ups/delivered_shipment_without_events_tracking_response')
    @carrier.expects(:commit).returns(tracking_response)
    result = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 'cypress', result.destination.city.downcase
    assert_equal 'TX', result.destination.state
  end

  def test_find_tracking_info_should_return_origin_address
    @carrier.expects(:commit).returns(@tracking_response)
    result = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 'naperville', result.origin.city.downcase
    assert_equal 'IL', result.origin.state
  end

  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 8, response.shipment_events.size
  end

  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end

  def test_find_tracking_info_should_have_correct_names_for_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
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
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal '175 AMBASSADOR', response.shipment_events.first.location.address1
    assert_equal 'K1N5X8', response.shipment_events.last.location.postal_code
  end

  def test_response_parsing
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( @locations[:beverly_hills],
                                    @locations[:real_home_as_residential],
                                    @packages.values_at(:chocolate_stuff))
    assert_equal [ "UPS Ground",
                   "UPS Three-Day Select",
                   "UPS Second Day Air",
                   "UPS Next Day Air Saver",
                   "UPS Next Day Air Early A.M.",
                   "UPS Next Day Air"], response.rates.map(&:service_name)
    assert_equal [992, 2191, 3007, 5509, 9401, 6124], response.rates.map(&:price)
    assert_equal [0, 0, 0, 0, 0, 0], response.rates.map(&:negotiated_rate)
  end

  def test_response_with_origin_account_parsing
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_with_origin_account_response')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( @locations[:beverly_hills],
                                     @locations[:real_home_as_residential],
                                     @packages[:chocolate_stuff])
    assert_equal [ "UPS Express",
                   "UPS Worldwide Expedited",
                   "UPS Worldwide Express Plus",
                   "UPS Saver"], response.rates.map(&:service_name)
    assert_equal [18893, 17856, 23473, 18286], response.rates.map(&:price)
    assert_equal [18704, 17677, 23238, 18103], response.rates.map(&:negotiated_rate)
   end

  def test_delivery_range_takes_weekend_into_consideration
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
    @carrier.expects(:commit).returns(mock_response)
    Timecop.freeze(DateTime.new(2012, 6, 15))
    response = @carrier.find_rates( @locations[:beverly_hills],
                                    @locations[:real_home_as_residential],
                                    @packages.values_at(:chocolate_stuff))

    date_test = [nil, 3, 2, 1, 1, 1].map do |days|
      DateTime.now.utc + days + 2 if days
    end
    Timecop.return

    assert_equal date_test, response.rates.map(&:delivery_date)
  end

  def test_maximum_weight
    assert Package.new(150 * 16, [5,5,5], :units => :imperial).mass == @carrier.maximum_weight
    assert Package.new((150 * 16) + 0.01, [5,5,5], :units => :imperial).mass > @carrier.maximum_weight
    assert Package.new((150 * 16) - 0.01, [5,5,5], :units => :imperial).mass < @carrier.maximum_weight
  end
end
