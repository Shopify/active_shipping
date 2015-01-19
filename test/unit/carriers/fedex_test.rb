require 'test_helper'

class FedExTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier           = FedEx.new(:key => '1111', :password => '2222', :account => '3333', :login => '4444')
    @tracking_response = xml_fixture('fedex/tracking_response')
  end

  def test_initialize_options_requirements
    assert_raises(ArgumentError) { FedEx.new }
    assert_raises(ArgumentError) { FedEx.new(:login => '999999999') }
    assert_raises(ArgumentError) { FedEx.new(:password => '7777777') }
    FedEx.new(:key => '999999999', :password => '7777777', :account => '123', :login => '123')
  end

  def test_business_days
    today = DateTime.civil(2013, 3, 12, 0, 0, 0, "-4")

    Timecop.freeze(today) do
      assert_equal DateTime.civil(2013, 3, 13, 0, 0, 0, "-4"), @carrier.send(:business_days_from, today, 1)
      assert_equal DateTime.civil(2013, 3, 15, 0, 0, 0, "-4"), @carrier.send(:business_days_from, today, 3)
      assert_equal DateTime.civil(2013, 3, 19, 0, 0, 0, "-4"), @carrier.send(:business_days_from, today, 5)
    end
  end

  def test_turn_around_time_default
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response').gsub('<v6:DeliveryTimestamp>2011-07-29</v6:DeliveryTimestamp>', '')

    today = DateTime.civil(2013, 3, 11, 0, 0, 0, "-4")

    Timecop.freeze(today) do
      delivery_date = Date.today + 7.days # FIVE_DAYS in fixture response, plus weekend
      timestamp = Time.now.iso8601
      @carrier.expects(:commit).with do |request, _options|
        parsed_response = Hash.from_xml(request)
        parsed_response['RateRequest']['RequestedShipment']['ShipTimestamp'] == timestamp
      end.returns(mock_response)

      destination = ActiveShipping::Location.from(location_fixtures[:beverly_hills].to_hash, :address_type => :commercial)
      response = @carrier.find_rates location_fixtures[:ottawa], destination, package_fixtures[:book], :test => true
      assert_equal [delivery_date, delivery_date], response.rates.first.delivery_range
    end
  end

  def test_turn_around_time
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response').gsub('<v6:DeliveryTimestamp>2011-07-29</v6:DeliveryTimestamp>', '')
    Timecop.freeze(DateTime.new(2013, 3, 11)) do
      delivery_date = Date.today + 8.days # FIVE_DAYS in fixture response, plus turn_around_time, plus weekend
      timestamp = (Time.now + 1.day).iso8601
      @carrier.expects(:commit).with do |request, _options|
        parsed_response = Hash.from_xml(request)
        parsed_response['RateRequest']['RequestedShipment']['ShipTimestamp'] == timestamp
      end.returns(mock_response)

      destination = ActiveShipping::Location.from(location_fixtures[:beverly_hills].to_hash, :address_type => :commercial)
      response = @carrier.find_rates location_fixtures[:ottawa], destination, package_fixtures[:book], :turn_around_time => 24, :test => true

      assert_equal [delivery_date, delivery_date], response.rates.first.delivery_range
    end
  end

  def test_transaction_id_sent_as_customer_transaction_id
    transaction_id = '9999-test'
    @carrier = FedEx.new(:key => '1111', :password => '2222', :account => '3333', :login => '4444', :transaction_id => transaction_id)
    @carrier.expects(:commit).with do |request, _options|
      parsed_request = Hash.from_xml(request)
      parsed_request['RateRequest']['TransactionDetail']['CustomerTransactionId'] == transaction_id
    end.returns(xml_fixture('fedex/ottawa_to_beverly_hills_rate_response'))

    destination = ActiveShipping::Location.from(location_fixtures[:beverly_hills].to_hash, :address_type => :commercial)
    @carrier.find_rates location_fixtures[:ottawa], destination, package_fixtures[:book], :test => true
  end

  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(@tracking_response)
    assert_instance_of ActiveShipping::TrackingResponse, @carrier.find_tracking_info('077973360403984', :test => true)
  end

  def test_find_tracking_info_should_mark_shipment_as_delivered
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal true, @carrier.find_tracking_info('077973360403984').delivered?
  end

  def test_find_tracking_info_should_return_correct_carrier
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal :fedex, @carrier.find_tracking_info('077973360403984').carrier
  end

  def test_find_tracking_info_should_return_correct_carrier_name
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'FedEx', @carrier.find_tracking_info('077973360403984').carrier_name
  end

  def test_find_tracking_info_should_return_correct_status
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal :delivered, @carrier.find_tracking_info('077973360403984').status
  end

  def test_find_tracking_info_should_return_correct_status_code
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'dl', @carrier.find_tracking_info('077973360403984').status_code.downcase
  end

  def test_find_tracking_info_should_return_correct_status_description
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'delivered', @carrier.find_tracking_info('1Z5FX0076803466397').status_description.downcase
  end

  def test_find_tracking_info_should_return_delivery_signature
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'KKING', @carrier.find_tracking_info('077973360403984').delivery_signature
  end

  def test_find_tracking_info_should_return_destination_address
    @carrier.expects(:commit).returns(@tracking_response)
    result = @carrier.find_tracking_info('077973360403984')
    assert_equal 'sacramento', result.destination.city.downcase
    assert_equal 'CA', result.destination.state
  end

  def test_find_tracking_info_should_gracefully_handle_missing_destination_information
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response_no_destination'))
    result = @carrier.find_tracking_info('077973360403984')
    assert_equal 'unknown', result.destination.city.downcase
    assert_equal 'unknown', result.destination.state
    assert_equal 'ZZ', result.destination.country.code(:alpha2).to_s
  end

  def test_find_tracking_info_should_gracefully_handle_empty_destination_information
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response_empty_destination'))
    result = @carrier.find_tracking_info('077973360403984')
    assert_equal 'unknown', result.destination.city.downcase
    assert_equal 'unknown', result.destination.state
    assert_equal 'ZZ', result.destination.country.code(:alpha2).to_s
  end

  def test_find_tracking_info_should_return_correct_shipper_address
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response_with_shipper_address'))
    response = @carrier.find_tracking_info('927489999894450502838')
    assert_equal 'wallingford', response.shipper_address.city.downcase
    assert_equal 'CT', response.shipper_address.state
  end

  def test_find_tracking_info_should_gracefully_handle_missing_shipper_address
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('077973360403984')
    assert_equal nil, response.shipper_address
  end

  def test_find_tracking_info_should_return_correct_ship_time
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('927489999894450502838')
    assert_equal Time.parse("2008-12-03T00:00:00").utc, response.ship_time
  end

  def test_find_tracking_info_should_gracefully_handle_missing_ship_time
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response_no_ship_time'))
    response = @carrier.find_tracking_info('927489999894450502838')
    assert_equal nil, response.ship_time
  end

  def test_find_tracking_info_should_return_correct_actual_delivery_date
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('077973360403984')
    assert_equal Time.parse('2008-12-08T07:43:37-08:00').utc, response.actual_delivery_date
  end

  def test_find_tracking_info_should_gracefully_handle_missing_actual_delivery_date
    # This particular fixture doesn't contain an actual delivery date
    # (in addition to having a shipper address)
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response_with_shipper_address'))
    response = @carrier.find_tracking_info('9274899998944505028386')
    assert_equal nil, response.actual_delivery_date
  end

  def test_find_tracking_info_should_return_correct_scheduled_delivery_date
    @carrier.expects(:commit).returns(xml_fixture('fedex/tracking_response_with_estimated_delivery_date'))
    response = @carrier.find_tracking_info('1234567890111')
    assert_equal Time.parse('2013-10-15T00:00:00').utc, response.scheduled_delivery_date
  end

  def test_find_tracking_info_should_gracefully_handle_missing_scheduled_delivery_date
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('077973360403984')
    assert_equal nil, response.scheduled_delivery_date
  end

  def test_find_tracking_info_should_return_origin_address
    @carrier.expects(:commit).returns(@tracking_response)
    result = @carrier.find_tracking_info('077973360403984')
    assert_equal 'nashville', result.origin.city.downcase
    assert_equal 'TN', result.origin.state
  end

  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_equal 6, response.shipment_events.size
  end

  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end

  def test_find_tracking_info_should_not_include_events_without_an_address
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('077973360403984', :test => true)
    assert_nil response.shipment_events.find { |event| event.name == 'Shipment information sent to FedEx' }
  end

  def test_building_request_with_address_type_commercial_should_not_include_residential
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response')
    expected_request = xml_fixture('fedex/ottawa_to_beverly_hills_commercial_rate_request')

    @carrier.expects(:ship_timestamp).returns(Time.parse("2009-07-20T12:01:55-04:00").in_time_zone('US/Eastern'))
    @carrier.expects(:commit).with { |request, test_mode| Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode }.returns(mock_response)
    destination = ActiveShipping::Location.from(location_fixtures[:beverly_hills].to_hash, :address_type => :commercial)
    @carrier.find_rates( location_fixtures[:ottawa],
                         destination,
                         package_fixtures.values_at(:book, :wii), :test => true)
  end

  def test_building_freight_request_and_parsing_response
    expected_request = xml_fixture('fedex/freight_rate_request')
    mock_response = xml_fixture('fedex/freight_rate_response')

    @carrier.expects(:ship_timestamp).returns(Time.parse("2013-11-01T14:04:01-07:00").in_time_zone('US/Pacific'))
    @carrier.expects(:commit).with { |request, test_mode| Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode }.returns(mock_response)

    # shipping and billing addresses below are provided by fedex test credentials

    shipping_location = Location.new( address1: '1202 Chalet Ln',
                                      address2: 'Do Not Delete - Test Account',
                                      city: 'Harrison',
                                      state: 'AR',
                                      postal_code: '72601',
                                      country: 'US')

    billing_location = Location.new(  address1: '2000 Freight LTL Testing',
                                      address2: 'Do Not Delete - Test Account',
                                      city: 'Harrison',
                                      state: 'AR',
                                      postal_code: '72601',
                                      country: 'US')

    freight_options = {
      account: '5555',
      billing_location: billing_location,
      payment_type: 'SENDER',
      freight_class: 'CLASS_050',
      packaging: 'PALLET',
      role: 'SHIPPER'
    }

    response = @carrier.find_rates( shipping_location,
                                    location_fixtures[:ottawa],
                                    [package_fixtures[:wii]],  :freight => freight_options, :test => true )

    assert_equal ["FedEx Freight Economy", "FedEx Freight Priority"], response.rates.map(&:service_name)
    assert_equal [66263, 68513], response.rates.map(&:price)

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert response.rates.length > 0, "There should've been more than 0 rates returned"

    rate = response.rates.first
    assert_equal 'FedEx', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal [package_fixtures[:wii]], rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end

  def test_building_request_and_parsing_response
    expected_request = xml_fixture('fedex/ottawa_to_beverly_hills_rate_request')
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response')
    @carrier.expects(:ship_timestamp).returns(Time.parse("2009-07-20T12:01:55-04:00").in_time_zone('US/Eastern'))
    @carrier.expects(:commit).with { |request, test_mode| Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode }.returns(mock_response)
    response = @carrier.find_rates( location_fixtures[:ottawa],
                                    location_fixtures[:beverly_hills],
                                    package_fixtures.values_at(:book, :wii), :test => true)
    assert_equal ["FedEx Ground"], response.rates.map(&:service_name)
    assert_equal [3836], response.rates.map(&:price)

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert response.rates.length > 0, "There should've been more than 0 rates returned"

    rate = response.rates.first
    assert_equal 'FedEx', rate.carrier
    assert_equal 'CAD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal package_fixtures.values_at(:book, :wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end

  def test_parsing_response_with_no_rate_reply
    expected_request = xml_fixture('fedex/ottawa_to_beverly_hills_rate_request')
    mock_response = xml_fixture('fedex/unknown_fedex_document_reply')

    @carrier.expects(:ship_timestamp).returns(Time.parse("2009-07-20T12:01:55-04:00").in_time_zone('US/Eastern'))
    @carrier.expects(:commit).with { |request, test_mode| Hash.from_xml(request) == Hash.from_xml(expected_request) && test_mode }.returns(mock_response)
    exception = assert_raises(ActiveShipping::ResponseContentError) do
      @carrier.find_rates( location_fixtures[:ottawa],
                           location_fixtures[:beverly_hills],
                           package_fixtures.values_at(:book, :wii), :test => true)
    end
    message = "Invalid document \n\n#{mock_response}"
    assert_equal message, exception.message
  end

  def test_service_name_for_code
    FedEx::SERVICE_TYPES.each do |capitalized_name, readable_name|
      assert_equal readable_name, FedEx.service_name_for_code(capitalized_name)
    end
  end

  def test_service_name_for_code_handles_yet_unknown_codes
    assert_equal "FedEx Express Saver Saturday Delivery", FedEx.service_name_for_code('FEDEX_EXPRESS_SAVER_SATURDAY_DELIVERY')
    assert_equal "FedEx Some Weird Rate", FedEx.service_name_for_code('SOME_WEIRD_RATE')
  end

  def test_delivery_range_based_on_delivery_date
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response').gsub('CAD', 'UKL')

    @carrier.expects(:commit).returns(mock_response)
    rate_estimates = @carrier.find_rates( location_fixtures[:ottawa],
                                          location_fixtures[:beverly_hills],
                                          package_fixtures.values_at(:book, :wii), :test => true)

    delivery_date = Date.new(2011, 7, 29)
    assert_equal delivery_date, rate_estimates.rates[0].delivery_date
    assert_equal [delivery_date] * 2, rate_estimates.rates[0].delivery_range
  end

  def test_delivery_date_from_transit_time
    mock_response = xml_fixture('fedex/raterequest_reply').gsub('CAD', 'UKL')

    @carrier.expects(:commit).returns(mock_response)

    today = DateTime.civil(2013, 3, 15, 0, 0, 0, "-4")

    Timecop.freeze(today) do
      rate_estimates = @carrier.find_rates( location_fixtures[:ottawa],
                                            location_fixtures[:beverly_hills],
                                            package_fixtures.values_at(:book, :wii), :test => true)

      # the above fixture will specify a transit time of 5 days, with 2 weekend days accounted for
      delivery_date = Date.today + 7
      assert_equal delivery_date, rate_estimates.rates[0].delivery_date
    end
  end

  def test_failure_to_parse_invalid_xml_results_in_a_useful_error
    mock_response = xml_fixture('fedex/invalid_fedex_reply')

    @carrier.expects(:commit).returns(mock_response)

    assert_raises ActiveShipping::ResponseContentError do
    @carrier.find_rates(
        location_fixtures[:ottawa],
        location_fixtures[:beverly_hills],
        package_fixtures.values_at(:book, :wii),
        :test => true
      )
    end
  end

  def test_response_without_notifications_raises_useful_error
    mock_response = xml_fixture('fedex/reply_without_notifications')

    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_rates(
      location_fixtures[:ottawa],
      location_fixtures[:beverly_hills],
      package_fixtures.values_at(:book, :wii),
      :test => true
    )

    assert response.success?
  end
end
