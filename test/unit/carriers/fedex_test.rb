require 'test_helper'

class FedExTest < ActiveSupport::TestCase
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
    today = DateTime.parse("Tue 12 Mar 2013 00:00:00-0400")

    Timecop.freeze(today) do
      assert_equal DateTime.parse("Wed 13 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 1)
      assert_equal DateTime.parse("Fri 15 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 3)
      assert_equal DateTime.parse("Mon 18 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 4)
      assert_equal DateTime.parse("Tue 19 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 5)
    end
  end

  def test_home_delivery_business_days
    today = DateTime.parse("Tue 12 Mar 2013 00:00:00-0400")

    Timecop.freeze(today) do
      assert_equal DateTime.parse("Wed 13 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 1, true)
      assert_equal DateTime.parse("Fri 15 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 3, true)
      assert_equal DateTime.parse("Sat 16 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 4, true)
      assert_equal DateTime.parse("Tue 19 Mar 2013 00:00:00-0400"), @carrier.send(:business_days_from, today, 5, true)
    end
  end

  def test_turn_around_time_default
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response').gsub('<v6:DeliveryTimestamp>2011-07-29</v6:DeliveryTimestamp>', '')

    today = Date.parse("Mon 11 Mar 2013")

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

  def test_parsing_response_with_no_system_code_for_one_rate_does_not_crash
    mock_response = xml_fixture('fedex/freight_rate_response').gsub('<v13:ServiceType>FEDEX_FREIGHT_ECONOMY</v13:ServiceType>','')

    @carrier.expects(:commit).returns(mock_response)
    @carrier.logger = Logger.new(StringIO.new)
    @carrier.logger.expects(:warn).once.with("[FedexParseRateError] Some fields where missing in the response: #{mock_response}")

    rates = @carrier.find_rates( location_fixtures[:ottawa], location_fixtures[:beverly_hills], package_fixtures.values_at(:book, :wii), :test => true)
    assert rates.rates.length == 1
    assert_equal rates.rates[0].service_code, 'FEDEX_FREIGHT_PRIORITY'
  end

  def test_parsing_response_with_no_system_code_on_any_shipping_rate
    mock_response = xml_fixture('fedex/freight_rate_response').gsub('<v13:ServiceType>FEDEX_FREIGHT_ECONOMY</v13:ServiceType>','').gsub('<v13:ServiceType>FEDEX_FREIGHT_PRIORITY</v13:ServiceType>','')

    @carrier.expects(:commit).returns(mock_response)
    @carrier.logger = Logger.new(StringIO.new)
    @carrier.logger.expects(:warn).once.with("[FedexParseRateError] Some fields where missing in the response: #{mock_response}")

    exception = assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_rates( location_fixtures[:ottawa], location_fixtures[:beverly_hills], package_fixtures.values_at(:book, :wii), :test => true)
    end
    message = "The response from the carrier contained errors and could not be treated"
    assert_equal exception.message, message
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

    today = Date.parse("Fri 15 Mar 2013")

    Timecop.freeze(today) do
      rate_estimates = @carrier.find_rates( location_fixtures[:ottawa],
                                            location_fixtures[:beverly_hills],
                                            package_fixtures.values_at(:book, :wii), :test => true)

      # the above fixture will specify a transit time of 5 days, with 2 weekend days accounted for
      delivery_date = Date.today + 5 + 2
      assert_equal delivery_date, rate_estimates.rates[0].delivery_date
    end
  end

  def test_delivery_date_from_ground_home_transit_time
    mock_response = xml_fixture('fedex/raterequest_response_with_ground_home_delivery')

    @carrier.expects(:commit).returns(mock_response)

    today = Date.parse("Thursday 04 Jun 2015")

    Timecop.freeze(today) do
      rate_estimates = @carrier.find_rates( location_fixtures[:ottawa],
                                            location_fixtures[:beverly_hills],
                                            package_fixtures.values_at(:book, :wii), :test => true)

      # the above fixture will specify a transit time of 3 days
      # for ground home, sunday and monday are non-biz days
      # so it is delivered on Tuesday
      delivery_date = Date.today + 3 + 2
      assert_equal delivery_date, rate_estimates.rates.first.delivery_date
    end
  end

  def test_delivery_date_from_ground_home_transit_time_on_saturday
    mock_response = xml_fixture('fedex/raterequest_response_with_ground_home_delivery')

    @carrier.expects(:commit).returns(mock_response)

    today = Date.parse("Wed 03 Jun 2015") #Wednesday

    Timecop.freeze(today) do
      rate_estimates = @carrier.find_rates( location_fixtures[:ottawa],
                                            location_fixtures[:beverly_hills],
                                            package_fixtures.values_at(:book, :wii), :test => true)

      # the above fixture will specify a transit time of 3 days
      # since ground home delivers on Saturday, there is no delay
      delivery_date = Date.today + 3
      assert_equal delivery_date, rate_estimates.rates.first.delivery_date
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

  def test_response_transient_failure
    mock_response = xml_fixture('fedex/tracking_response_failure_code_9045')
    @carrier.expects(:commit).returns(mock_response)

    error = assert_raises(ActiveShipping::ShipmentNotFound) do
      @carrier.find_tracking_info('123456789013')
    end

    msg = 'Sorry, we are unable to process your tracking request.  Please retry later, or contact Customer Service at 1.800.Go.FedEx(R) 800.463.3339.'
    assert_equal msg, error.message
  end

  def test_response_terminal_failure
    mock_response = xml_fixture('fedex/tracking_response_failure_code_9080')
    @carrier.expects(:commit).returns(mock_response)

    error = assert_raises(ActiveShipping::ResponseContentError) do
      @carrier.find_tracking_info('123456789013')
    end

    msg = 'Sorry, we are unable to process your tracking request.  Please contact Customer Service at 1.800.Go.FedEx(R) 800.463.3339.'
    assert_equal msg, error.message
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
    assert_nil response.scheduled_delivery_date
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
    assert_equal 'PU', response.shipment_events.first.type_code
    assert_equal 'OC', response.shipment_events.second.type_code
    assert_equal 'AR', response.shipment_events.third.type_code
  end

  def test_tracking_info_for_delivered_at_door
    mock_response = xml_fixture('fedex/tracking_response_delivered_at_door')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('403934084723025')
    assert_equal '403934084723025', response.tracking_number
    assert response.delivered?
    refute response.exception?
    assert_equal 10, response.shipment_events.length
    assert_equal 'PU', response.shipment_events.first.type_code
    assert_equal 'OC', response.shipment_events.second.type_code
    assert_equal 'AR', response.shipment_events.third.type_code
    assert_equal 'Delivered', response.latest_event.name
    assert_equal 'DL', response.latest_event.type_code
    assert_nil response.delivery_signature
  end

  def test_state_degrades_to_unknown
    mock_response = xml_fixture('fedex/tracking_response_with_blank_state')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('798701052354')

    destination_address = ActiveShipping::Location.new(
      city: 'SAITAMA',
      country: 'Japan',
      state: 'unknown'
    )

    assert_equal destination_address.to_hash, response.destination.to_hash
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
    assert_nil response.delivery_signature

    assert_equal Time.parse('2014-11-17T22:39:00+11:00'), response.ship_time
    assert_nil response.scheduled_delivery_date
    assert_nil response.actual_delivery_date

    assert_nil response.origin

    destination_address = ActiveShipping::Location.new(
      city: 'GRAFTON',
      country: 'AU',
      state: 'ON'
    )
    assert_equal destination_address.to_hash, response.destination.to_hash

    assert_equal 1, response.shipment_events.length
    assert_equal 'In transit', response.latest_event.name
    assert_equal 'IT', response.latest_event.type_code
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
    assert_nil response.scheduled_delivery_date
    assert_nil response.actual_delivery_date

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
    assert_equal "SE", response.latest_event.type_code
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

  def test_tracking_info_with_uncovered_error
    mock_response = xml_fixture('fedex/tracking_response_invalid_tracking_number')
    @carrier.expects(:commit).returns(mock_response)

    error = assert_raises(ActiveShipping::ResponseContentError) do
      @carrier.find_tracking_info('123456789013')
    end

    msg = 'Invalid tracking numbers. Please check the following numbers and resubmit.'
    assert_equal msg, error.message
  end

  def test_tracking_info_with_empty_status_detail
    mock_response = xml_fixture('fedex/tracking_response_empty_status_detail')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_tracking_info('123456789012')

    assert_equal '123456789012', response.tracking_number
    assert_nil response.status_code
    assert_nil response.status
    assert_nil response.status_description
    assert_nil response.delivery_signature
    assert_empty response.shipment_events
  end

  def test_tracking_info_with_missing_status_code
    mock_response = xml_fixture('fedex/tracking_response_missing_status_code')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_tracking_info('123456789012')
    assert_equal '123456789012', response.tracking_number
    assert_nil response.status_code
    assert_nil response.status
    assert_nil response.status_description
    assert_nil response.delivery_signature
    assert_empty response.shipment_events
  end

  def test_create_shipment
    confirm_response = xml_fixture('fedex/create_shipment_response')
    @carrier.stubs(:commit).returns(confirm_response)

    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york],
      package_fixtures.values_at(:chocolate_stuff),
      :test => true
    )

    # These assertions are to check that the xml fixture is extracted properly.
    assert_equal 1, response.labels.count
    assert_equal response.labels.first.tracking_number, "794637052920"
    assert_equal response.labels.first.img_data.size, 8286
  end

  def test_create_shipment_signature_option
    packages = package_fixtures.values_at(:chocolate_stuff)
    packages.each {|p| p.options[:signature_option] = :indirect }
    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         packages,
                                         :test => true))
    assert_equal result.search('SpecialServicesRequested/SpecialServiceTypes').text, "SIGNATURE_OPTION"
    assert_equal result.search('SpecialServicesRequested/SignatureOptionDetail').text.strip, "INDIRECT"
  end

  def test_create_shipment_reference
    packages = package_fixtures.values_at(:wii)
    packages.each do |p|
      p.options[:reference_numbers] = [
        { :value => "FOO-123"},
        { :type => "INVOICE_NUMBER", :value => "BAR-456" }
      ]
    end

    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         packages,
                                         :test => true))

    assert_equal result.search('RequestedPackageLineItems/CustomerReferences[first()]/Value').text, "FOO-123"
    assert_equal result.search('RequestedPackageLineItems/CustomerReferences[first()]/CustomerReferenceType').text, "CUSTOMER_REFERENCE"
    assert_equal result.search('RequestedPackageLineItems/CustomerReferences[last()]/Value').text, "BAR-456"
    assert_equal result.search('RequestedPackageLineItems/CustomerReferences[last()]/CustomerReferenceType').text, "INVOICE_NUMBER"
  end

  def test_create_shipment_label_format_option
    packages = package_fixtures.values_at(:chocolate_stuff)
    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         packages,
                                         :label_format => 'ZPLII',
                                         :test => true))
    assert_equal result.search('RequestedShipment/LabelSpecification/ImageType').text, "ZPLII"
  end

  def test_create_shipment_default_label_stock_type
    packages = package_fixtures.values_at(:wii)

    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         packages,
                                         :test => true))

    assert_equal result.search('RequestedShipment/LabelSpecification/LabelStockType').text, FedEx::DEFAULT_LABEL_STOCK_TYPE
  end

  def test_create_shipment_label_stock_type
    label_stock_type = 'PAPER_4X6'
    packages = package_fixtures.values_at(:wii)

    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         packages,
                                         :test => true,
                                         :label_stock_type => label_stock_type))

    assert_equal result.search('RequestedShipment/LabelSpecification/LabelStockType').text, label_stock_type
  end

  def test_maximum_address_field_length
    assert_equal 35, @carrier.maximum_address_field_length
  end
end
