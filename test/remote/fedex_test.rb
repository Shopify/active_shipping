require 'test_helper'

class FedExTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = FedEx.new(credentials(:fedex).merge(:test => true))
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

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

  def test_tracking
    p response = @carrier.find_tracking_info('123456789012', :test => true)
    assert response
  end

  def test_tracking_with_bad_number
    assert_raises(ResponseError) do
      @carrier.find_tracking_info('12345')
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

    assert_not_equal residential_response.rates.map(&:price), commercial_response.rates.map(&:price)
  end
end
