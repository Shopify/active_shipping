require 'test_helper'

class FedExTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = FedEx.new(:key => '1111', :password => '2222', :account => '3333', :login => '4444')
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

  def test_parsing_response_without_notifications
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

  ### find_tracking_info

  def test_tracking_info_for_delivered_with_signature
    mock_response = xml_fixture('fedex/tracking_response_delivered_with_signature')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('449044304137821')
    assert_equal '449044304137821', response.tracking_number
    assert_equal 'AVILLALON', response.delivery_signature
    assert response.delivered?
    refute response.exception?

    assert_equal Date.parse('2013-12-30'), response.ship_time
    assert_equal nil, response.scheduled_delivery_date
    assert_equal Time.parse('2014-01-02T18:23:29Z'), response.actual_delivery_date

    origin_address = ActiveShipping::Location.new(
      city: 'JEFFERSONVILLE',
      country: 'US',
      state: 'IN'
    )
    assert_equal origin_address.to_hash, response.origin.to_hash

    destination_address = ActiveShipping::Location.new(
      city: 'Miami',
      country: 'US',
      state: 'FL'
    )
    assert_equal destination_address.to_hash, response.destination.to_hash

    assert_equal 11, response.shipment_events.length
    assert_equal 'Delivered', response.latest_event.name
  end

  def test_tracking_info_for_delivered_at_door
    mock_response = xml_fixture('fedex/tracking_response_delivered_at_door')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('403934084723025')
    assert_equal '403934084723025', response.tracking_number
    assert response.delivered?
    refute response.exception?
    assert_equal 10, response.shipment_events.length
    assert_equal 'Delivered', response.latest_event.name
    assert_equal nil, response.delivery_signature
  end

  def test_tracking_info_for_in_transit
    mock_response = xml_fixture('fedex/tracking_response_in_transit')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('123456789012')
    refute response.delivered?
    refute response.exception?

    assert_equal '123456789012', response.tracking_number
    assert_equal :fedex, response.carrier
    assert_equal 'FedEx', response.carrier_name
    assert_equal :in_transit, response.status
    assert_equal 'IT', response.status_code
    assert_equal "Package available for clearance", response.status_description
    assert_equal nil, response.delivery_signature

    assert_equal Time.parse('2014-11-17T22:39:00+11:00'), response.ship_time
    assert_equal nil, response.scheduled_delivery_date
    assert_equal nil, response.actual_delivery_date

    assert_equal nil, response.origin

    destination_address = ActiveShipping::Location.new(
      city: 'GRAFTON',
      country: 'AU',
      state: 'ON'
    )
    assert_equal destination_address.to_hash, response.destination.to_hash

    assert_equal 1, response.shipment_events.length
    assert_equal 'In transit', response.latest_event.name
  end

  def test_tracking_info_for_shipment_exception
    mock_response = xml_fixture('fedex/tracking_response_shipment_exception')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('957794015041323')
    assert_equal '957794015041323', response.tracking_number
    refute response.delivered?
    assert response.exception?
    assert_equal :exception, response.status
    assert_equal "Unable to deliver", response.status_description

    assert_equal Date.parse('2014-01-27'), response.ship_time
    assert_equal nil, response.scheduled_delivery_date
    assert_equal nil, response.actual_delivery_date

    origin_address = ActiveShipping::Location.new(
      city: 'AUSTIN',
      country: 'US',
      state: 'TX'
    )
    assert_equal origin_address.to_hash, response.origin.to_hash

    destination_address = ActiveShipping::Location.new(
      city: 'GOOSE CREEK',
      country: 'US',
      state: 'SC'
    )
    assert_equal destination_address.to_hash, response.destination.to_hash

    assert_equal 8, response.shipment_events.length
    assert_equal "Shipment exception", response.latest_event.name
  end

  def test_tracking_info_without_status
    mock_response = xml_fixture('fedex/tracking_response_multiple_results')
    @carrier.expects(:commit).returns(mock_response)

    error = assert_raises(ActiveShipping::Error) do
      @carrier.find_tracking_info('123456789012')
    end

    msg = 'Multiple matches were found. Specify a unqiue identifier: 2456987000~123456789012~FX, 2456979001~123456789012~FX, 2456979000~123456789012~FX'
    assert_equal msg, error.message
  end

  def test_tracking_info_with_unknown_tracking_number
    mock_response = xml_fixture('fedex/tracking_response_not_found')
    @carrier.expects(:commit).returns(mock_response)

    error = assert_raises(ActiveShipping::ShipmentNotFound) do
      @carrier.find_tracking_info('123456789013')
    end

    msg = 'This tracking number cannot be found. Please check the number or contact the sender.'
    assert_equal msg, error.message
  end

  def test_tracking_info_with_bad_tracking_number
    mock_response = xml_fixture('fedex/tracking_response_bad_tracking_number')
    @carrier.expects(:commit).returns(mock_response)

    assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_tracking_info('abc')
    end
  end
end
