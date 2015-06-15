require 'test_helper'

class StampsTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Stamps.new(integration_id: 'i', username: 'u', password: 'p')
    @items   = [{ :sku => 'AF0001', :quantity => 1 }, { :sku => 'AF0002', :quantity => 2 }]
    @authentication_response = xml_fixture('stamps/authenticate_user_response')
  end

  def test_authenticate_user
    response_chain(xml_fixture('stamps/get_account_info_response'))
    @carrier.account_info
  end

  def test_account_info
    response_chain(xml_fixture('stamps/get_account_info_response'))

    account_info = @carrier.account_info

    assert_equal 'ActiveShipping::StampsAccountInfoResponse', account_info.class.name

    assert_equal '1234567', account_info.customer_id
    assert_equal '1029384756', account_info.meter_number
    assert_equal '7654321', account_info.user_id

    assert_equal '123.45', account_info.available_postage
    assert_equal '543.21', account_info.control_total
    assert_equal '250', account_info.max_postage_balance

    assert_equal 'Los Angeles', account_info.lpo.city
    assert_equal 'CA', account_info.lpo.state
    assert_equal '90066', account_info.lpo.zip

    assert_equal true, account_info.can_print_shipping?
    assert_equal true, account_info.can_use_cost_codes?
    assert_equal true, account_info.can_use_hidden_postage?
    assert_equal true, account_info.can_purchase_sdc_insurance?
    assert_equal true, account_info.can_print_memo?
    assert_equal true, account_info.can_print_international?
    assert_equal true, account_info.can_purchase_postage?
    assert_equal true, account_info.can_edit_cost_codes?
    assert_equal false, account_info.must_use_cost_codes?
    assert_equal true, account_info.can_view_online_reports?

    assert_equal '987.65', account_info.per_print_limit
  end

  def test_purchase_postage
    response_chain(xml_fixture('stamps/purchase_postage_response'))

    purchase_status = @carrier.purchase_postage('543.21', '123.45')

    assert_equal 'ActiveShipping::StampsPurchasePostageResponse', purchase_status.class.name

    assert_equal 'Pending', purchase_status.purchase_status
    assert_equal '1234', purchase_status.transaction_id
    assert_equal '543.21', purchase_status.available_postage
    assert_equal '123.45', purchase_status.control_total
  end

  def test_purchase_status
    response_chain(xml_fixture('stamps/get_purchase_status_response'))

    purchase_status = @carrier.purchase_status('1234')

    assert_equal 'ActiveShipping::StampsPurchasePostageResponse', purchase_status.class.name

    assert_equal 'Success', purchase_status.purchase_status
    assert_equal nil, purchase_status.transaction_id
  end

  def test_validate_address
    response_chain(xml_fixture('stamps/cleanse_address_response'))

    location = Location.new(
      name:     'Geoff Anton',
      company:  'stamps.com',
      address1: '12959 Coral Tree Pl',
      city:     'Los Angeles',
      state:    'CA',
      zip:      '90066'
    )
    cleansed_address = @carrier.validate_address(location)

    assert_equal 'ActiveShipping::StampsCleanseAddressResponse', cleansed_address.class.name

    assert_equal true, cleansed_address.address_match?
    assert_equal true, cleansed_address.city_state_zip_ok?
    assert_equal 'GEOFF ANTON', cleansed_address.address.name
    assert_equal 'STAMPS.COM', cleansed_address.address.company
    assert_equal '12959 CORAL TREE PL', cleansed_address.address.address1
    assert_equal 'LOS ANGELES', cleansed_address.address.city
    assert_equal 'CA', cleansed_address.address.state
    assert_equal '90066-7020', cleansed_address.address.zip
    assert_equal '7SWYAzuNh82cWhIQyRFXRNa71HFkZWFkYmVlZg==20100210', cleansed_address.cleanse_hash
    assert_equal 'Tdwp4JlTc02DhscYxbI7l7o08apkZWFkYmVlZg==20100210', cleansed_address.override_hash
  end

  def test_get_rates
    response_chain(xml_fixture('stamps/get_rates_response'))

    origin = Location.new(zip: '90405')
    destination = Location.new(zip: '90066')
    package = Package.new((12 * 16), [1, 2, 3], value: 100.00, units: :imperial)

    rates = @carrier.find_rates(origin, destination, package)

    assert_equal 'ActiveShipping::RateResponse', rates.class.name

    assert_equal 2, rates.rates.length

    assert_equal 'ActiveShipping::StampsRateEstimate', rates.rates[0].class.name

    rate = rates.rates.first
    assert_equal '90405', rate.origin.zip
    assert_equal '90066', rate.destination.zip
    assert_equal 'US-PM', rate.service_code
    assert_equal 'USPS Priority Mail', rate.service_name
    assert_equal 'USD', rate.currency
    assert_equal Date.new(2014, 1, 31), rate.shipping_date
    assert_equal [Date.new(2014, 2, 1), Date.new(2014, 2, 3)], rate.delivery_range
    assert_equal Date.new(2014, 2, 3), rate.delivery_date
    assert_equal 1217, rate.price
    assert_equal 260, rate.insurance_price
    assert_equal %w(US-A-SC US-A-CM), rate.add_ons['US-A-DC'][:prohibited_with]
    assert_equal '2.6', rate.add_ons['SC-A-INS'][:amount]
    assert_equal %w(US-A-REG US-A-INS), rate.add_ons['SC-A-INS'][:prohibited_with]
    assert_equal 17, rate.available_add_ons.length
  end

  def test_create_shipment
    response_chain(xml_fixture('stamps/create_indicium_response'))

    origin = Location.new(
      name:     'Some Body',
      address1: '3420 Ocean Park Bl',
      address2: 'Ste 1000',
      city:     'Santa Monica',
      state:    'CA',
      zip:      '90405'
    )

    destination = Location.new(
      name:     'GEOFF ANTON',
      compnay:  'STAMPS.COM',
      address1: '12959 CORAL TREE PL',
      city:     'LOS ANGELES',
      state:    'CA',
      zip:      '90066-7020'
    )

    package = Package.new((12 * 16), [], units: :imperial)

    options = { service: 'US-PM', insured_value: 100, add_ons: %w(US-A-DC SC-A-INS)}

    indicium = @carrier.create_shipment(origin, destination, package, [], options)

    assert_equal 'ActiveShipping::StampsShippingResponse', indicium.class.name

    assert_equal '1234567890ABCDEF', indicium.shipping_id
    assert_equal '9101010521290895036903', indicium.tracking_number

    assert_equal '90405', indicium.rate.origin.zip
    assert_equal '90066', indicium.rate.destination.zip
    assert_equal 'US-PM', indicium.rate.service_code
    assert_equal 'USPS Priority Mail', indicium.rate.service_name
    assert_equal 'USD', indicium.rate.currency
    assert_equal Date.new(2009, 8, 31), indicium.rate.shipping_date
    assert_equal [Date.new(2009, 9, 1), Date.new(2009, 9, 3)], indicium.rate.delivery_range
    assert_equal Date.new(2009, 9, 3), indicium.rate.delivery_date
    assert_equal 1036, indicium.rate.price
    assert_equal 185, indicium.rate.insurance_price
    assert_equal Hash.new, indicium.rate.add_ons['US-A-DC']
    assert_equal '1.85', indicium.rate.add_ons['SC-A-INS'][:amount]
    assert_equal %w(US-A-DC SC-A-INS), indicium.rate.available_add_ons

    assert_equal '0dd49299-d89c-4997-b8ac-28db5542edc9', indicium.stamps_tx_id

    assert_equal '123.45', indicium.available_postage
    assert_equal '543.21', indicium.control_total
  end

  def test_track_shipment
    response_chain(xml_fixture('stamps/track_shipment_response'))

    tracking_response = @carrier.find_tracking_info('c605aec1-322e-48d5-bf81-b0bb820f9c22', stamps_tx_id: true)

    assert_equal 'ActiveShipping::TrackingResponse', tracking_response.class.name

    assert_equal 3, tracking_response.shipment_events.length

    assert_equal 'Electronic Notification', tracking_response.shipment_events[0].name
    assert_equal '90066', tracking_response.shipment_events[0].location.zip
    assert_equal 'United States', tracking_response.shipment_events[0].location.country.name
    assert_equal Time.utc(2008, 2, 13, 16, 9, 0), tracking_response.shipment_events[0].time

    assert_equal 'PROCESSED', tracking_response.shipment_events[1].name
    assert_equal 'INDIANAPOLIS', tracking_response.shipment_events[1].location.city
    assert_equal 'IN', tracking_response.shipment_events[1].location.state
    assert_equal '46206', tracking_response.shipment_events[1].location.zip
    assert_equal 'United States', tracking_response.shipment_events[1].location.country.name
    assert_equal Time.utc(2008, 2, 15, 16, 58, 0), tracking_response.shipment_events[1].time

    assert_equal 'DELIVERED', tracking_response.shipment_events[2].name
    assert_equal 'FORT WAYNE', tracking_response.shipment_events[2].location.city
    assert_equal 'IN', tracking_response.shipment_events[2].location.state
    assert_equal '46809', tracking_response.shipment_events[2].location.zip
    assert_equal 'United States', tracking_response.shipment_events[2].location.country.name
    assert_equal Time.utc(2008, 2, 19, 10, 32, 0), tracking_response.shipment_events[2].time

    assert_equal :delivered, tracking_response.status
    assert_equal 'Delivered', tracking_response.status_code
  end

  def test_authenticator_renewal
    fixtures = [
      @authentication_response,
      xml_fixture('stamps/get_account_info_response'),
      xml_fixture('stamps/expired_authenticator_response'),
      @authentication_response,
      xml_fixture('stamps/get_account_info_response')
    ]

    @carrier.expects(:ssl_post).times(5).returns(*fixtures)

    # The first call gets initial authenticator, second call receives
    # expired authenticator
    @carrier.account_info
    account_info = @carrier.account_info

    assert_equal 'ActiveShipping::StampsAccountInfoResponse', account_info.class.name
  end

  private

  def response_chain(primary_response)
    @carrier.expects(:ssl_post).twice.returns(@authentication_response, primary_response)
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end
end
