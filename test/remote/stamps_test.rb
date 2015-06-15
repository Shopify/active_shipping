require 'test_helper'

class RemoteStampsTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Stamps.new(credentials(:stamps).merge(test: true))
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_account_info
    skip 'ActiveShipping::ResponseError: Unable to write data to the transport connection: An existing connection was forcibly closed by the remote host.'
    @account_info = @carrier.account_info

    assert_equal 'ActiveShipping::StampsAccountInfoResponse', @account_info.class.name
  end

  def test_purchase_postage
    skip '<#<ActiveShipping::ResponseError: Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host.>>.'
    purchase_amount = 10.62 # Based on the amount used in the track shipment tests

    account = @carrier.account_info
    response = @carrier.purchase_postage(purchase_amount, account.control_total)
    assert response.success?
  end

  def test_validation_domestic
    response = @carrier.validate_address(location_fixtures[:new_york_with_name])

    assert_equal 'BOB BOBSEN', response.address.name
    assert_equal '780 3RD AVE RM 2601', response.address.address1
    assert_nil response.address.address2
    assert_equal 'NEW YORK', response.address.city
    assert_equal 'NY', response.address.state
    assert_equal '10017-2177', response.address.zip

    assert_equal [], response.candidate_addresses

    assert response.address_match?
    assert response.city_state_zip_ok?

    assert_instance_of String, response.cleanse_hash
    assert_instance_of String, response.override_hash
  end

  def test_validation_puerto_rico
    puerto_rico_with_name = Location.new(location_fixtures[:puerto_rico].to_hash.merge(name: 'Bob Bobsen'))

    response = @carrier.validate_address(puerto_rico_with_name)

    assert_equal 'BOB BOBSEN', response.address.name
    assert_equal '1 CALLE NUEVA', response.address.address1
    assert_equal 'BARCELONETA', response.address.city
    assert_equal 'PR', response.address.province
    assert_equal '00617-3101', response.address.postal_code

    assert_equal [], response.candidate_addresses

    assert response.address_match?
    assert response.city_state_zip_ok?

    assert_instance_of String, response.cleanse_hash
    assert_instance_of String, response.override_hash
  end

  def test_validatation_ottawa
    ottawa_with_name = Location.new(location_fixtures[:ottawa].to_hash.merge(name: 'Bob Bobsen'))

    response = @carrier.validate_address(ottawa_with_name)

    assert_equal 'BOB BOBSEN', response.address.name
    assert_equal '110 LAURIER AVENUE WEST', response.address.address1
    assert_equal 'OTTAWA', response.address.city
    assert_equal 'ON', response.address.province
    assert_equal 'K1P 1J1', response.address.postal_code
    assert_equal 'CA', response.address.country_code
    assert_equal '1-613-580-2400', response.address.phone

    assert_equal [], response.candidate_addresses

    assert response.address_match?
    assert response.city_state_zip_ok?

    assert_instance_of String, response.cleanse_hash
    assert_instance_of String, response.override_hash
  end

  def test_validation_with_candidates
    missing_quadrant = Location.new(
      name: 'The White House',
      address1: '1600 Pennsylvania Ave',
      city: 'Washington',
      state: 'DC',
      zip: '20500'
    )

    response = @carrier.validate_address(missing_quadrant)

    assert_equal 'THE WHITE HOUSE', response.address.name
    assert_equal '1600 PENNSYLVANIA AVE NW', response.address.address1
    assert_equal 'WASHINGTON', response.address.city
    assert_equal 'DC', response.address.province
    assert_equal '20500-0003', response.address.postal_code

    assert_equal 7, response.candidate_addresses.length

    assert !response.address_match?
    assert response.city_state_zip_ok?

    assert_nil response.cleanse_hash
    assert_instance_of String, response.override_hash
  end

  def test_shipment
    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york_with_name],
      package_fixtures[:book],
      [],

      service: 'US-PM',
      image_type: 'Epl',
      return_image_data: true,
      sample_only: true
    )

    assert_equal 'Stamps', response.rate.carrier
    assert_equal 'USPS Priority Mail', response.rate.service_name
    assert_equal 'US-PM', response.rate.service_code
    assert_equal 'USD', response.rate.currency
    assert_equal '90210', response.rate.origin.zip
    assert_equal '10017', response.rate.destination.zip
    assert_equal 'US', response.rate.destination.country_code

    assert_instance_of Fixnum, response.rate.total_price
    assert_instance_of String, response.stamps_tx_id

    assert_nil response.label_url

    assert_equal ";\r\n; ", response.image[0..4]
  end

  def test_international_shipment
    ottawa_with_name = Location.new(location_fixtures[:ottawa].to_hash.merge(name: 'Bob Bobsen'))

    response = @carrier.create_shipment(
      location_fixtures[:new_york_with_name],
      ottawa_with_name,
      package_fixtures[:declared_value],
      line_item_fixture,

      service: 'US-PMI',
      content_type: 'Merchandise',
      sample_only: true

    )

    assert_equal 'Stamps', response.rate.carrier
    assert_equal 'USPS Priority Mail International', response.rate.service_name
    assert_equal 'US-PMI', response.rate.service_code
    assert_equal 'USD', response.rate.currency
    assert_equal '10017', response.rate.origin.zip
    assert_equal 'K1P 1J1', response.rate.destination.zip
    assert_equal 'CA', response.rate.destination.country_code

    assert_instance_of Fixnum, response.rate.total_price
    assert_instance_of String, response.stamps_tx_id
    assert_instance_of String, response.label_url

    assert_equal "https://", response.label_url[0..7]
    assert_equal "%PDF", response.image[0..3]
  end

  def test_track_shipment
    skip '<#<ActiveShipping::ResponseError: Insufficient Postage>>.'

    # Tracking is not available for sample only shipments
    shipment = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york_with_name],
      package_fixtures[:book],
      [],

      service: 'US-MM',
      insured_value: 70,
      add_ons: %w(US-A-INS US-A-DC)

    )
    tracking = @carrier.find_tracking_info(shipment.tracking_number)

    assert_equal :stamps, tracking.carrier
    assert_equal "Stamps", tracking.carrier_name
    assert_equal :electronic_notification, tracking.status
    assert_equal "ElectronicNotification", tracking.status_code

    assert_equal 1, tracking.shipment_events.length

    event = tracking.shipment_events.first
    assert_equal "Electronic Notification", event.name
    assert_equal "90210", event.location.zip

    assert_instance_of Time, event.time
  end

  def test_track_with_stamps_tx_id
    skip '<#<ActiveShipping::ResponseError: Insufficient Postage>>.'
    # Tracking is not available for sample only shipments
    shipment = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york_with_name],
      package_fixtures[:book],
      [],

      service: 'US-MM',
      insured_value: 70,
      add_ons: %w(US-A-INS US-A-DC)
    )
    tracking = @carrier.find_tracking_info(shipment.stamps_tx_id, stamps_tx_id: true)

    assert_equal :stamps, tracking.carrier
    assert_equal "Stamps", tracking.carrier_name
    assert_equal :electronic_notification, tracking.status
    assert_equal "ElectronicNotification", tracking.status_code

    assert_equal 1, tracking.shipment_events.length

    event = tracking.shipment_events.first
    assert_equal "Electronic Notification", event.name
    assert_equal "90210", event.location.zip

    assert_instance_of Time, event.time
  end

  def test_tracking_with_bad_number
    assert_raises(ResponseError) do
      @carrier.find_tracking_info('abc123xyz')
    end
  end

  def test_zip_to_zip
    response = @carrier.find_rates(
      Location.new(:zip => 40524),
      Location.new(:zip => 40515),
      Package.new(16, [12, 6, 2], units: :imperial)
    )
    assert response.success?
  end

  def test_add_ons
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york],
      package_fixtures[:book],
      add_ons: 'US-A-DC'
    )

    assert response.success?, response.message
  end

  def test_just_country_given
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      Location.new(:country => 'CZ'),
      Package.new(100, [5, 10, 20])
    )

    assert response.success?, response.message
  end

  def test_us_to_canada
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:ottawa],
      package_fixtures[:american_wii]
    )

    refute response.rates.empty?
  end

  def test_domestic_rates
    response = @carrier.find_rates(
      location_fixtures[:new_york],
      location_fixtures[:beverly_hills],
      package_fixtures[:american_wii]
    )

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    refute response.rates.empty?

    rate = response.rates.first
    assert_equal 'Stamps', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates

    package = rate.packages.first
    assert_equal package_fixtures[:american_wii].weight, package.weight
    assert_equal package_fixtures[:american_wii].inches, package.inches
    assert_equal package_fixtures[:american_wii].value, package.value
    assert_equal package_fixtures[:american_wii].options[:units], package.options[:units]
  end

  def test_international_rates
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:ottawa],
      package_fixtures[:book]
    )

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    refute response.rates.empty?

    rate = response.rates.first
    assert_equal 'Stamps', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates

    package = rate.packages.first
    assert_equal package_fixtures[:book].weight, package.weight
    assert_equal package_fixtures[:book].inches, package.inches
  end

  def test_us_to_us_possession
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:puerto_rico],
      package_fixtures[:american_wii]
    )

    refute response.rates.empty?
  end

  def test_bare_packages_domestic
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills], # imperial (U.S. origin)
      location_fixtures[:new_york],
      Package.new(0, 0)
    )

    assert response.success?, response.message
  end

  def test_bare_packages_international
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills], # imperial (U.S. origin)
      location_fixtures[:ottawa],
      Package.new(0, 0)
    )
    assert response.success?, response.message
  end

  def test_first_class_packages_with_mail_type
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills], # imperial (U.S. origin)
      location_fixtures[:new_york],
      Package.new(0, 0),

      service: 'US-FC',
      package_type: 'Package'
    )

    assert response.success?, response.message
  end

  def test_first_class_packages_with_invalid_mail_type
    assert_raises(ResponseError) do
      @carrier.find_rates(
        location_fixtures[:beverly_hills], # imperial (U.S. origin)
        location_fixtures[:new_york],
        Package.new(0, 0),

        service: 'US-FC',
        package_type: 'Invalid'
      )
    end
  end
end
