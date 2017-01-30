require 'test_helper'

class UPSTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier   = UPS.new(
                   :key => 'key',
                   :login => 'login',
                   :password => 'password'
                 )
    @tracking_response = xml_fixture('ups/shipment_from_tiger_direct')
    @delivery_dates_response = xml_fixture('ups/delivery_dates_response')
  end

  def test_initialize_options_requirements
    assert_raises(ArgumentError) { UPS.new }
    assert_raises(ArgumentError) { UPS.new(:login => 'blah', :password => 'bloo') }
    assert_raises(ArgumentError) { UPS.new(:login => 'blah', :key => 'kee') }
    assert_raises(ArgumentError) { UPS.new(:password => 'bloo', :key => 'kee') }
    assert UPS.new(:login => 'blah', :password => 'bloo', :key => 'kee')
  end

  def test_find_tracking_info_should_create_correct_xml
    xml_request = xml_fixture('ups/access_request') + xml_fixture('ups/tracking_request')
    @carrier.expects(:commit).with(:track, xml_request, true).returns(@tracking_response)
    @carrier.find_tracking_info('1Z5FX0076803466397', :tracking_option => '03', :test => true)
  end

  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'ActiveShipping::TrackingResponse', @carrier.find_tracking_info('1Z5FX0076803466397').class.name
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

  def test_find_tracking_info_should_return_delivery_signature
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'MCAULEY', @carrier.find_tracking_info('1Z5FX0076803466397').delivery_signature
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

  def test_find_tracking_info_should_return_delivered_if_event_is_not_latest
    tracking_response = xml_fixture('ups/delivered_shipment_with_refund')
    @carrier.expects(:commit).returns(tracking_response)
    result = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal :delivered, result.status
    assert_equal true, result.delivered?
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
    assert_equal ["BILLING INFORMATION RECEIVED",
                  "IMPORT SCAN",
                  "LOCATION SCAN",
                  "LOCATION SCAN",
                  "DEPARTURE SCAN",
                  "ARRIVAL SCAN",
                  "OUT FOR DELIVERY",
                  "DELIVERED"], response.shipment_events.map(&:name)
  end

  def test_find_tracking_info_should_have_messages_for_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal ["BILLING INFORMATION RECEIVED",
                  "IMPORT SCAN",
                  "LOCATION SCAN",
                  "LOCATION SCAN",
                  "DEPARTURE SCAN",
                  "ARRIVAL SCAN",
                  "OUT FOR DELIVERY",
                  "DELIVERED"], response.shipment_events.map(&:message)
  end

  def test_find_tracking_info_should_have_correct_type_codes_for_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal ["M", "I", "I", "I", "I", "I", "I", "D"], response.shipment_events.map(&:type_code)
  end

  def test_add_origin_and_destination_data_to_shipment_events_where_appropriate
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal '175 AMBASSADOR', response.shipment_events.first.location.address1
    assert_equal 'K1N5X8', response.shipment_events.last.location.postal_code
  end

  def test_find_tracking_info_should_return_correct_actual_delivery_date
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal Time.parse('2008-06-25 11:19:00 UTC'), response.actual_delivery_date
  end

  def test_find_tracking_info_should_return_correct_rescheduled_delivery_date
    @carrier.expects(:commit).returns(xml_fixture('ups/rescheduled_shipment'))
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal Time.parse('2015-01-29 00:00:00 UTC'), response.scheduled_delivery_date
  end

  def test_find_tracking_info_should_handle_no_status_node
    @carrier.expects(:commit).returns(xml_fixture('ups/no_status_node_success'))
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 'Success', response.params.fetch("Response").fetch("ResponseStatusDescription")
    assert_empty response.shipment_events
  end

  def test_response_parsing_an_oversize_package
    mock_response = xml_fixture('ups/package_exceeds_maximum_length')
    @carrier.expects(:commit).returns(mock_response)

    e = assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_rates(location_fixtures[:beverly_hills],
                          location_fixtures[:real_home_as_residential],
                          package_fixtures.values_at(:chocolate_stuff))
    end

    assert_equal "Failure: Package exceeds the maximum length constraint of 108 inches. Length is the longest side of a package.", e.message
  end

  def test_handles_no_shipment_warning_messages
    mock_response = xml_fixture('ups/no_shipment_warnings')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates(location_fixtures[:beverly_hills],
                        location_fixtures[:real_home_as_residential],
                        package_fixtures.values_at(:chocolate_stuff))
    rate = response.rates.first
    assert_equal [], rate.messages
  end

  def test_handles_warning_messages
    mock_response = xml_fixture('ups/no_negotiated_rates')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates(location_fixtures[:beverly_hills],
                        location_fixtures[:real_home_as_residential],
                        package_fixtures.values_at(:chocolate_stuff))
    rate = response.rates.first
    expected_messages = [
      "User Id and Shipper Number combination is not qualified to receive negotiated rates.",
      "Your invoice may vary from the displayed reference rates",
      "Ship To Address Classification is changed from Residential to Commercial"
    ]
    assert_equal expected_messages, rate.messages
  end

  def test_response_parsing_an_undecoded_character
    unencoded_response = @tracking_response.gsub('NAPERVILLE', "N\xc4PERVILLE")
    @carrier.stubs(:ssl_post).returns(unencoded_response)
    response = @carrier.find_tracking_info('1Z5FX0076803466397')
    assert_equal 'NÄPERVILLE', response.shipment_events.first.location.city
  end

  def test_response_parsing_an_unknown_error
    mock_response = '<RatingServiceSelectionResponse><Response><ResponseStatusCode>0</ResponseStatusCode></Response></RatingServiceSelectionResponse>'
    @carrier.expects(:commit).returns(mock_response)

    e = assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_rates(location_fixtures[:beverly_hills],
                          location_fixtures[:real_home_as_residential],
                          package_fixtures.values_at(:chocolate_stuff))
    end

    assert_equal "UPS could not process the request.", e.message
  end

  def test_response_parsing
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( location_fixtures[:beverly_hills],
                                    location_fixtures[:real_home_as_residential],
                                    package_fixtures.values_at(:chocolate_stuff))
    assert_equal ["UPS Ground",
                  "UPS Three-Day Select",
                  "UPS Second Day Air",
                  "UPS Next Day Air Saver",
                  "UPS Next Day Air Early A.M.",
                  "UPS Next Day Air"], response.rates.map(&:service_name)
    assert_equal [992, 2191, 3007, 5509, 9401, 6124], response.rates.map(&:price)
    assert_equal [0, 0, 0, 0, 0, 0], response.rates.map(&:negotiated_rate)
  end

  def test_response_with_insured_value
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response_with_insured')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( location_fixtures[:beverly_hills],
                                    location_fixtures[:real_home_as_residential],
                                    package_fixtures.values_at(:declared_value))
    assert_equal ["UPS Ground",
                  "UPS Three-Day Select",
                  "UPS Second Day Air",
                  "UPS Next Day Air Saver",
                  "UPS Next Day Air Early A.M.",
                  "UPS Next Day Air"], response.rates.map(&:service_name)
    assert_equal [2254, 4002, 5107, 8726, 12730, 9430], response.rates.map(&:price)
    assert_equal [850, 850, 850, 850, 850, 850], response.rates.map(&:insurance_price)
    assert_equal [0, 0, 0, 0, 0, 0], response.rates.map(&:negotiated_rate)
  end

  def test_response_with_origin_account_parsing
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_with_origin_account_response')
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.find_rates( location_fixtures[:beverly_hills],
                                    location_fixtures[:real_home_as_residential],
                                    package_fixtures[:chocolate_stuff])
    assert_equal ["UPS Express",
                  "UPS Worldwide Expedited",
                  "UPS Worldwide Express Plus",
                  "UPS Saver"], response.rates.map(&:service_name)
    assert_equal [18893, 17856, 23473, 18286], response.rates.map(&:price)
    assert_equal [18704, 17677, 23238, 18103], response.rates.map(&:negotiated_rate)
  end

  def test_delivery_range_takes_weekend_into_consideration
    mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
    @carrier.expects(:commit).returns(mock_response)

    Timecop.freeze(DateTime.new(2012, 6, 15)) do
      response = @carrier.find_rates( location_fixtures[:beverly_hills],
                                      location_fixtures[:real_home_as_residential],
                                      package_fixtures.values_at(:chocolate_stuff))

      date_test = [nil, 3, 2, 1, 1, 1].map do |days|
        DateTime.now.utc + (days + 2).days if days
      end

      assert_equal date_test, response.rates.map(&:delivery_date)
    end
  end

  def test_maximum_weight
    assert Package.new(150 * 16, [5, 5, 5], :units => :imperial).mass == @carrier.maximum_weight
    assert Package.new((150 * 16) + 0.01, [5, 5, 5], :units => :imperial).mass > @carrier.maximum_weight
    assert Package.new((150 * 16) - 0.01, [5, 5, 5], :units => :imperial).mass < @carrier.maximum_weight
  end

  def test_obtain_multiple_labels
    confirm_response = xml_fixture('ups/triple_confirm_response')
    accept_response = xml_fixture('ups/triple_accept_response')
    @carrier.stubs(:commit).returns(confirm_response, accept_response)

    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york],
      package_fixtures.values_at(:chocolate_stuff, :book, :american_wii),
      :test => true,
      :destination => {
         :company_name => 'N.A.',
         :phone_number => '123-123-1234',
         :attention_name => 'Jane Doe'
       }

    )

    # Sanity checks.  Hmm.  That looks a lot like a type check.
    assert_instance_of LabelResponse, response
    assert_equal 3, response.labels.count

    # These tracking numbers are part of the fixture data.  What we're trying
    # to verify is that the data in the XML is extracted properly.
    tracking = response.labels.map { |label| label.tracking_number }
    assert_includes tracking, "1ZA03R691594829862"
    assert_includes tracking, "1ZA03R691592132475"
    assert_includes tracking, "1ZA03R691590470881"

    pictures = response.labels.map { |label| label.img_data }
    refute_includes pictures, nil
  end

  def test_obtain_single_label
    confirm_response = xml_fixture('ups/shipment_confirm_response')
    accept_response = xml_fixture('ups/shipment_accept_response')
    @carrier.stubs(:commit).returns(confirm_response, accept_response)

    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york],
      package_fixtures.values_at(:chocolate_stuff),
      :test => true,
      :destination => {
         :company_name => 'N.A.',
         :phone_number => '123-123-1234',
         :attention_name => 'Jane Doe'
       }

    )

    # Sanity checks.  Hmm.  That looks a lot like a type check.
    assert_instance_of LabelResponse, response
    assert_equal 1, response.labels.count

    # These tracking numbers are part of the fixture data.  What we're trying
    # to verify is that the data in the XML is extracted properly.
    tracking = response.labels.map { |label| label.tracking_number }
    assert_includes tracking, "1ZA03R691591538440"

    pictures = response.labels.map { |label| label.img_data }
    refute_includes pictures, nil
  end

  def test_saturday_delivery
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:annapolis],
                                           package_fixtures.values_at(:chocolate_stuff),
                                           :test => true,
                                           :saturday_delivery => true
                             )

    saturday = response.search '/ShipmentConfirmRequest/Shipment/ShipmentServiceOptions/SaturdayDelivery'
    refute_empty saturday
  end

  def test_label_request_prepay
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:annapolis],
                                           package_fixtures.values_at(:chocolate_stuff),
                                           :test => true,
                                           :prepay => true
                             )

    prepay = response.search '/ShipmentConfirmRequest/Shipment/PaymentInformation/Prepaid'
    refute_empty prepay
  end

  def test_label_request_bill_third_party
    expected_account_number = "A01B24"
    expected_postal_code_number = "97013"
    expected_country_code = "US"
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:annapolis],
                                           package_fixtures.values_at(:chocolate_stuff),
                                           :test => true,
                                           :bill_third_party => true,
                                           :billing_account => expected_account_number,
                                           :billing_zip => expected_postal_code_number,
                                           :billing_country => expected_country_code)

    assert_equal expected_account_number, response.search('ShipmentConfirmRequest/Shipment/ItemizedPaymentInformation/ShipmentCharge/BillThirdParty/BillThirdPartyShipper/AccountNumber').text
    assert_equal expected_postal_code_number, response.search('/ShipmentConfirmRequest/Shipment/ItemizedPaymentInformation/ShipmentCharge/BillThirdParty/BillThirdPartyShipper/ThirdParty/Address/PostalCode').text
    assert_equal expected_country_code, response.search('/ShipmentConfirmRequest/Shipment/ItemizedPaymentInformation/ShipmentCharge/BillThirdParty/BillThirdPartyShipper/ThirdParty/Address/CountryCode').text
  end

  def test_label_request_negotiated_rates_presence
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:annapolis],
                                           package_fixtures.values_at(:chocolate_stuff),
                                           :test => true,
                                           :saturday_delivery => true,
                                           :origin_account => 'A01B23', # without this option, a negotiated rate will not be requested
                                           :negotiated_rates => true,
                             )

    negotiated_rates = response.search '/ShipmentConfirmRequest/Shipment/RateInformation/NegotiatedRatesIndicator'
    refute_empty negotiated_rates
  end

  def test_label_request_different_shipper
    pickup   = location_fixtures[:beverly_hills]
    deliver  = location_fixtures[:annapolis]
    shipper  = location_fixtures[:fake_google_as_commercial]
    packages = package_fixtures.values_at(:chocolate_stuff)

    result   = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                           pickup, deliver, packages,  :test => true, :shipper => shipper ))

    address = result.search '/ShipmentConfirmRequest/Shipment/Shipper/Address/AddressLine1'
    assert_equal address.text, shipper.address1
    refute_equal address.text, pickup.address1
  end

  def test_label_request_domestic_reference_numbers
    # Domestic Shipments use package level reference numbers
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:annapolis],
                                           package_fixtures.values_at(:chocolate_stuff),
                                           :test => true,
                                           :reference_numbers => [{value: 'REF_NUM'}]
                             )
    ref_vals = response.search '/ShipmentConfirmRequest/Shipment/Package/ReferenceNumber/Value'
    assert_equal ref_vals.first.text, 'REF_NUM'
  end

  def test_label_request_international_reference_numbers
    # International Shipments use shipment level reference numbers
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:ottawa_with_name],
                                           package_fixtures.values_at(:books),
                                           :test => true,
                                           :reference_numbers => [{value: 'REF_NUM'}]
                             )
    ref_vals = response.search '/ShipmentConfirmRequest/Shipment/ReferenceNumber/Value'
    assert_equal ref_vals.first.text, 'REF_NUM'
  end

  def test_label_request_international_with_paperless_invoice
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:ottawa_with_name],
                                           package_fixtures.values_at(:books),
                                           :test => true,
                                           :paperless_invoice => true
                             )
    international_form = response.search '/ShipmentConfirmRequest/Shipment/ShipmentServiceOptions/InternationalForms'
    refute_empty international_form
  end

  def test_label_request_international_with_delivery_duty_paid
    # setting terms_of_shipment to DDP, Delivery Duty Paid, means the shipper will pay duties and taxes
    response = Nokogiri::XML @carrier.send(:build_shipment_request,
                                           location_fixtures[:beverly_hills],
                                           location_fixtures[:ottawa_with_name],
                                           package_fixtures.values_at(:books),
                                           :test => true,
                                           :paperless_invoice => true,
                                           :terms_of_shipment => 'DDP'
                             )
    terms_of_shipment = response.search '/ShipmentConfirmRequest/Shipment/ShipmentServiceOptions/InternationalForms/TermsOfShipment'
    duties_and_taxes_payment_info = response.css('ShipmentCharge Type:contains("02")').first.parent

    refute_empty terms_of_shipment
    refute_empty duties_and_taxes_payment_info.search('BillShipper')
  end

  def test_label_request_shipment_level_delivery_confirmation
    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:ottawa_with_name],
                                         package_fixtures.values_at(:chocolate_stuff),
                                         :test => true,
                                         :delivery_confirmation => :delivery_confirmation_adult_signature_required))
    assert_equal '2', result.search('/ShipmentConfirmRequest/Shipment/ShipmentServiceOptions/DeliveryConfirmation/DCISType').text
  end

  def test_label_request_package_level_delivery_confirmation
    packages = package_fixtures.values_at(:chocolate_stuff)
    packages.each {|p| p.options[:delivery_confirmation] = :delivery_confirmation }
    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         packages,
                                         :test => true))
    assert_equal '1', result.search('/ShipmentConfirmRequest/Shipment/Package/PackageServiceOptions/DeliveryConfirmation/DCISType').text
  end

  def test_label_request_shipment_level_delivery_confirmation_moved_to_package_level
    # Domestic shipments should have their delivery confirmation specified at package level and not shipment-level
    result = Nokogiri::XML(@carrier.send(:build_shipment_request,
                                         location_fixtures[:beverly_hills],
                                         location_fixtures[:annapolis],
                                         package_fixtures.values_at(:chocolate_stuff),
                                         :test => true,
                                         :delivery_confirmation => :delivery_confirmation))
    assert_equal '1', result.search('/ShipmentConfirmRequest/Shipment/Package/PackageServiceOptions/DeliveryConfirmation/DCISType').text
    assert_empty result.search('/ShipmentConfirmRequest/Shipment/ShipmentServiceOptions/DeliveryConfirmation/DCISType').text
  end

  def test_get_delivery_date_estimates_can_parse_delivery_estimates
    @carrier.expects(:commit).returns(@delivery_dates_response)
    monday = Date.parse('0201', '%m%d') # Feb to avoid holidays http://www.ups.com/content/us/en/resources/ship/imp_exp/operation.html
    monday += 1.day while monday.wday != 1

    response = @carrier.get_delivery_date_estimates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:real_home_as_residential],
      package_fixtures.values_at(:books),
      pickup_date=monday,
      {
        :test => true
      }
    )
    assert response.is_a?(ActiveShipping::DeliveryDateEstimatesResponse)
    assert_equal 6, response.delivery_estimates.size
    ground_estimate = response.delivery_estimates.select{ |de| de.service_name == "UPS Ground"}.first
    assert_equal Date.parse('2015-02-5'), ground_estimate.date
    assert_equal 3, ground_estimate.business_transit_days
  end

  def test_get_delivery_date_estimates_can_translate_service_codes
    # The TimeInTransit API returns service codes that are different from those used by
    # other API's. So we need to translate the codes into the ones used elsewhere.
    @carrier.expects(:commit).returns(@delivery_dates_response)
    monday = Date.parse('0201', '%m%d') # Feb to avoid holidays http://www.ups.com/content/us/en/resources/ship/imp_exp/operation.html
    monday += 1.day while monday.wday != 1

    response = @carrier.get_delivery_date_estimates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:real_home_as_residential],
      package_fixtures.values_at(:books),
      pickup_date=monday,
      {
        :test => true
      }
    )

    response.delivery_estimates.each do |delivery_estimate|
      assert_equal delivery_estimate.service_code, UPS::DEFAULT_SERVICE_NAME_TO_CODE[delivery_estimate.service_name]
    end
  end

  def test_get_rates_for_single_serivce
    mock_response = xml_fixture("ups/rate_single_service")
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_rates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:real_home_as_residential],
      package_fixtures.values_at(:books),
      {
        :service => UPS::DEFAULT_SERVICE_NAME_TO_CODE["UPS Ground"],
        :test => true
      }
    )
    assert_equal ["UPS Ground"], response.rates.map(&:service_name)
  end

  def test_void_shipment
    mock_response = xml_fixture("ups/void_shipment_response")
    @carrier.expects(:commit).returns(mock_response)
    response = @carrier.void_shipment('1Z12345E0390817264')
    assert response
  end

  def test_maximum_address_field_length
    assert_equal 35, @carrier.maximum_address_field_length
  end

  def test_package_surepost_less_than_one_lb_service
    xml_builder = Nokogiri::XML::Builder.new do |xml|
      @carrier.send(:build_package_node,
                    xml,
                    package_fixtures[:small_half_pound],
                    {
                      :service => "92",
                      :imperial => true
                    }
      )
    end
    request = Nokogiri::XML(xml_builder.to_xml)
    assert_equal 'OZS', request.search('/Package/PackageWeight/UnitOfMeasurement/Code').text
    assert_equal '8.0', request.search('/Package/PackageWeight/Weight').text
  end

  def test_package_surepost_less_than_one_lb_service_code
    xml_builder = Nokogiri::XML::Builder.new do |xml|
      @carrier.send(:build_package_node,
                    xml,
                    package_fixtures[:small_half_pound],
                    {
                      :service_code => "92",
                      :imperial => true
                    }
      )
    end
    request = Nokogiri::XML(xml_builder.to_xml)
    assert_equal 'OZS', request.search('/Package/PackageWeight/UnitOfMeasurement/Code').text
    assert_equal '8.0', request.search('/Package/PackageWeight/Weight').text
  end

  def test_address_validation
    location = Location.new(address1: "55 Glenlake Parkway", city: "Atlanta", state: "GA", zip: "30328", country: "US")
    address_validation_response = xml_fixture('ups/address_validation_response')
    @carrier.expects(:commit).returns(address_validation_response)
    response = @carrier.validate_address(location)
    assert_equal :commercial, response.classification
    assert_equal true, response.address_match?
  end

  def test_address_validation_ambiguous
    location = Location.new(address1: "55 Glen", city: "Atlanta", state: "GA", zip: "30328", country: "US")
    address_validation_response = xml_fixture('ups/address_validation_response_ambiguous')
    @carrier.expects(:commit).returns(address_validation_response)
    response = @carrier.validate_address(location)
    assert_equal false, response.address_match?
    assert_equal :ambiguous, response.validity
  end

  def test_address_validation_no_candidates
    location = Location.new(address1: "55 Glenblagahrhadd", city: "Atlanta", state: "GA", zip: "30321", country: "US")
    address_validation_response = xml_fixture('ups/address_validation_response_no_candidates')
    @carrier.expects(:commit).returns(address_validation_response)
    response = @carrier.validate_address(location)
    assert_equal false, response.address_match?
    assert_equal :invalid, response.validity
  end

end
