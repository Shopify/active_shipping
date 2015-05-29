require 'test_helper'

class RemoteFedExTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = FedEx.new(credentials(:fedex).merge(:test => true))
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  ### valid_credentials?

  def test_valid_credentials
    valid_carrier = FedEx.new(credentials(:fedex))
    assert valid_carrier.valid_credentials?

    invalid_carrier = FedEx.new(credentials(:fedex).merge(password: 'invalid'))
    refute invalid_carrier.valid_credentials?
  end

  ### find_rates

  def test_us_to_canada
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:ottawa],
      package_fixtures.values_at(:wii)
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_freight
    skip 'Cannot find the fedex freight creds. Whomp, whomp.'
    freight = credentials(:fedex_freight)

    shipping_location = Location.new( address1: freight[:shipping_address1],
                                      address2: freight[:shipping_address2],
                                      city: freight[:shipping_city],
                                      state: freight[:shipping_state],
                                      postal_code: freight[:shipping_postal_code],
                                      country: freight[:shipping_country])

    billing_location = Location.new(  address1: freight[:billing_address1],
                                      address2: freight[:billing_address2],
                                      city: freight[:billing_city],
                                      state: freight[:billing_state],
                                      postal_code: freight[:billing_postal_code],
                                      country: freight[:billing_country])

    freight_options = {
      account: freight[:account],
      billing_location: billing_location,
      payment_type: freight[:payment_type],
      freight_class: freight[:freight_class],
      packaging: freight[:packaging],
      role: freight[:role]
    }

    response = @carrier.find_rates(
      shipping_location,
      location_fixtures[:ottawa],
      package_fixtures.values_at(:wii),
      freight: freight_options
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_zip_to_zip_fails
    @carrier.find_rates(
      Location.new(:zip => 40524),
      Location.new(:zip => 40515),
      package_fixtures[:wii]
    )
  rescue ResponseError => e
    assert_match /country\s?code/i, e.message
    assert_match /(missing|invalid)/, e.message
  end

  # FedEx requires a valid origin and destination postal code
  def test_rates_for_locations_with_only_zip_and_country
    response = @carrier.find_rates(
                 location_fixtures[:bare_beverly_hills],
                 location_fixtures[:bare_ottawa],
                 package_fixtures.values_at(:wii)
               )

    assert response.rates.size > 0
  end

  def test_rates_for_location_with_only_country_code
    @carrier.find_rates(
      location_fixtures[:bare_beverly_hills],
      Location.new(:country => 'CA'),
      package_fixtures.values_at(:wii)
    )
  rescue ResponseError => e
    assert_match /postal code/i, e.message
    assert_match /(missing|invalid)/i, e.message
  end

  def test_invalid_recipient_country
    @carrier.find_rates(
      location_fixtures[:bare_beverly_hills],
      Location.new(:country => 'JP', :zip => '108-8361'),
      package_fixtures.values_at(:wii)
    )
  rescue ResponseError => e
    assert_match /postal code/i, e.message
    assert_match /(missing|invalid)/i, e.message
  end

  def test_ottawa_to_beverly_hills
    response = @carrier.find_rates(
      location_fixtures[:ottawa],
      location_fixtures[:beverly_hills],
      package_fixtures.values_at(:book, :wii)
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_ottawa_to_london
    response = @carrier.find_rates(
      location_fixtures[:ottawa],
      location_fixtures[:london],
      package_fixtures.values_at(:book, :wii)
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_beverly_hills_to_netherlands
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:netherlands],
      package_fixtures.values_at(:book, :wii)
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_beverly_hills_to_new_york
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york],
      package_fixtures.values_at(:book, :wii)
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_beverly_hills_to_london
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:london],
      package_fixtures.values_at(:book, :wii)
    )

    assert_instance_of Array, response.rates
    assert response.rates.length > 0
    response.rates.each do |rate|
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.price
    end
  end

  def test_different_rates_for_commercial
    residential_response = @carrier.find_rates(
                             location_fixtures[:beverly_hills],
                             location_fixtures[:ottawa],
                             package_fixtures.values_at(:chocolate_stuff)
                           )
    commercial_response  = @carrier.find_rates(
                             location_fixtures[:beverly_hills],
                             Location.from(location_fixtures[:ottawa].to_hash, :address_type => :commercial),
                             package_fixtures.values_at(:chocolate_stuff)
                           )

    refute_equal residential_response.rates.map(&:price), commercial_response.rates.map(&:price)
  end

  ### find_tracking_info

  def test_find_tracking_info_for_delivered_shipment
    # unfortunately, we have to use Fedex unique identifiers, because the test tracking numbers are overloaded.
    response = @carrier.find_tracking_info('123456789012', unique_identifier: '2456987000~123456789012~FX')
    assert response.success?
    assert response.delivered?
    assert_equal '123456789012', response.tracking_number
    assert_equal :delivered, response.status
    assert_equal 'DL', response.status_code
    assert_equal "Delivered", response.status_description

    assert_equal Time.parse('2014-11-14T03:49:00Z'), response.ship_time
    assert_equal nil, response.scheduled_delivery_date
    assert_equal Time.parse('2014-12-05T00:28:00Z'), response.actual_delivery_date

    assert_equal nil, response.origin

    destination_address = ActiveShipping::Location.new(
      city: 'COLLIERVILLE',
      country: 'US',
      state: 'TN'
    )
    assert_equal destination_address.to_hash, response.destination.to_hash
    assert_equal 1, response.shipment_events.length
  end

  def test_find_tracking_info_for_in_transit_shipment_1
    # unfortunately, we have to use Fedex unique identifiers, because the test tracking numbers are overloaded.
    response = @carrier.find_tracking_info('123456789012', unique_identifier: '2456979001~123456789012~FX')
    assert response.success?
    refute response.delivered?
    assert_equal '123456789012', response.tracking_number
    assert_equal :in_transit, response.status
    assert_equal 'IT', response.status_code
    assert_equal "Package available for clearance", response.status_description
    assert_equal 1, response.shipment_events.length
    assert_nil response.actual_delivery_date
    assert_equal nil, response.scheduled_delivery_date
  end

  def test_find_tracking_info_for_in_transit_shipment_2
    # unfortunately, we have to use Fedex unique identifiers, because the test tracking numbers are overloaded.
    response = @carrier.find_tracking_info('123456789012', unique_identifier: '2456979000~123456789012~FX')
    assert response.success?
    refute response.delivered?
    assert_equal '123456789012', response.tracking_number
    assert_equal :in_transit, response.status
    assert_equal 'IT', response.status_code
    assert_equal "In transit", response.status_description

    assert_equal Time.parse('2014-11-25T20:04:00Z'), response.ship_time
    assert_equal nil, response.scheduled_delivery_date
    assert_equal nil, response.actual_delivery_date

    assert_equal nil, response.origin

    destination_address = ActiveShipping::Location.new(
      city: 'TONNESSEE',
      country: 'US',
      state: 'TN'
    )
    assert_equal destination_address.to_hash, response.destination.to_hash
    assert_equal 9, response.shipment_events.length
  end

  def test_find_tracking_info_with_multiple_matches
    exception = assert_raises(ActiveShipping::Error) do
      response = @carrier.find_tracking_info('123456789012')
    end
    assert_match 'Multiple matches were found.', exception.message
  end

  def test_find_tracking_info_not_found
    assert_raises(ActiveShipping::ShipmentNotFound) do
      @carrier.find_tracking_info('123456789013')
    end
  end

  def test_find_tracking_info_with_invalid_tracking_number
    assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_tracking_info('abc')
    end
  end

  def test_obtain_shipping_label
    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills_with_name],
      location_fixtures[:new_york_with_name],
      package_fixtures[:wii],
        :test => true,
        :reference_number => {
          :value => "FOO-123",
          :code => "PO"
        }
    )

    assert response.success?
    refute_empty response.labels
    refute_empty response.labels.first.img_data
  end

  def test_obtain_shipping_label_with_signature_option
    packages = package_fixtures.values_at(:wii)
    packages.each {|p| p.options[:signature_option] = :adult }

    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills_with_name],
      location_fixtures[:new_york_with_name],
      packages,
      {:test => true}
    )

    signature_option = response.params["ProcessShipmentReply"]["CompletedShipmentDetail"]["CompletedPackageDetails"]["SignatureOption"]
    assert_equal FedEx::SIGNATURE_OPTION_CODES[:adult], signature_option
  end
end
