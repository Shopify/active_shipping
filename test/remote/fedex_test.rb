require 'test_helper'

class FedExTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = FedEx.new(fixtures(:fedex).merge(:test => true))
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_us_to_canada
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:ottawa],
                   @packages.values_at(:wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_freight
    response = nil
    freight = fixtures(:fedex_freight)

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

    assert_nothing_raised do
      response = @carrier.find_rates(
                   shipping_location,
                   @locations[:ottawa],
                   @packages.values_at(:wii),
                   freight: freight_options
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_zip_to_zip_fails
    @carrier.find_rates(
      Location.new(:zip => 40524),
      Location.new(:zip => 40515),
      @packages[:wii]
    )
  rescue ResponseError => e
    assert_match /country\s?code/i, e.message
    assert_match /(missing|invalid)/, e.message
  end

  # FedEx requires a valid origin and destination postal code
  def test_rates_for_locations_with_only_zip_and_country
    response = @carrier.find_rates(
                 @locations[:bare_beverly_hills],
                 @locations[:bare_ottawa],
                 @packages.values_at(:wii)
               )

    assert response.rates.size > 0
  end

  def test_rates_for_location_with_only_country_code
    response = @carrier.find_rates(
                 @locations[:bare_beverly_hills],
                 Location.new(:country => 'CA'),
                 @packages.values_at(:wii)
               )
  rescue ResponseError => e
    assert_match /postal code/i, e.message
    assert_match /(missing|invalid)/i, e.message
  end

  def test_invalid_recipient_country
    response = @carrier.find_rates(
                 @locations[:bare_beverly_hills],
                 Location.new(:country => 'JP', :zip => '108-8361'),
                 @packages.values_at(:wii)
               )
  rescue ResponseError => e
    assert_match /postal code/i, e.message
    assert_match /(missing|invalid)/i, e.message
  end

  def test_ottawa_to_beverly_hills
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_ottawa_to_london
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:london],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_beverly_hills_to_netherlands
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:netherlands],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_beverly_hills_to_new_york
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:new_york],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_beverly_hills_to_london
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:london],
                   @packages.values_at(:book, :wii)
                 )
      assert !response.rates.blank?
      response.rates.each do |rate|
        assert_instance_of String, rate.service_name
        assert_instance_of Fixnum, rate.price
      end
    end
  end

  def test_tracking
    assert_nothing_raised do
      @carrier.find_tracking_info('123456789012', :test => true)
    end
  end

  def test_tracking_with_bad_number
    assert_raises ResponseError do
      response = @carrier.find_tracking_info('12345')
    end
  end

  def test_different_rates_for_commercial
    residential_response = @carrier.find_rates(
                             @locations[:beverly_hills],
                             @locations[:ottawa],
                             @packages.values_at(:chocolate_stuff)
                           )
    commercial_response  = @carrier.find_rates(
                             @locations[:beverly_hills],
                             Location.from(@locations[:ottawa].to_hash, :address_type => :commercial),
                             @packages.values_at(:chocolate_stuff)
                           )

    assert_not_equal residential_response.rates.map(&:price), commercial_response.rates.map(&:price)
  end
end
