require 'test_helper'

class RemoteUPSTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @options = credentials(:ups).merge(:test => true)
    @carrier = UPS.new(@options)
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_tracking
    response = @carrier.find_tracking_info('1Z12345E0291980793')
    assert response.success?
  end

  def test_tracking_with_bad_number
    assert_raises ResponseError do
      @carrier.find_tracking_info('1Z12345E029198079')
    end
  end

  def test_tracking_with_another_number
    response = @carrier.find_tracking_info('1Z12345E6692804405')
    assert response.success?
  end

  def test_us_to_uk
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:london],
      package_fixtures.values_at(:big_half_pound),
      :test => true
    )

    assert response.success?
    refute response.rates.empty?
  end

  def test_puerto_rico
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      Location.new(:city => 'Ponce', :country => 'PR', :zip => '00733-1283'),
      package_fixtures.values_at(:big_half_pound),
      :test => true
    )

    assert response.success?
    refute response.rates.empty?
  end

  def test_just_country_given
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      Location.new(:country => 'CA'),
      Package.new(100, [5, 10, 20])
    )

    refute response.rates.empty?
  end

  def test_ottawa_to_beverly_hills
    response = @carrier.find_rates(
      location_fixtures[:ottawa],
      location_fixtures[:beverly_hills],
      package_fixtures.values_at(:book, :wii),
      :test => true
    )

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    refute response.rates.empty?

    rate = response.rates.first
    assert_equal 'UPS', rate.carrier
    assert_equal 'CAD', rate.currency
    if @options[:origin_account]
      assert_instance_of Fixnum, rate.negotiated_rate
    else
      assert_equal rate.negotiated_rate, 0
    end
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

  def test_ottawa_to_us_fails_without_zip
    assert_raises(ResponseError) do
      response = @carrier.find_rates(
        location_fixtures[:ottawa],
        Location.new(:country => 'US'),
        package_fixtures.values_at(:book, :wii),
        :test => true
      )
    end
  end

  def test_ottawa_to_us_succeeds_with_only_zip
    response = @carrier.find_rates(
      location_fixtures[:ottawa],
      Location.new(:country => 'US', :zip => 90210),
      package_fixtures.values_at(:book, :wii),
      :test => true
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_us_to_uk_with_different_pickup_types
    daily_response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:london],
      package_fixtures.values_at(:book, :wii),
      :pickup_type => :daily_pickup,
      :test => true
    )
    one_time_response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:london],
      package_fixtures.values_at(:book, :wii),
      :pickup_type => :one_time_pickup,
      :test => true
    )

    refute_equal daily_response.rates.map(&:price), one_time_response.rates.map(&:price)
  end

  def test_bare_packages
    p = Package.new(0, 0)

    response = @carrier.find_rates(
                 location_fixtures[:beverly_hills], # imperial (U.S. origin)
                 location_fixtures[:ottawa],
                 p,
                 :test => true
               )

    assert response.success?, response.message
    refute response.rates.empty?

    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:beverly_hills], # metric
                 p,
                 :test => true
               )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_different_rates_based_on_address_type
    responses = {}
    locations = [
      :fake_home_as_residential, :fake_home_as_commercial,
      :fake_google_as_residential, :fake_google_as_commercial
    ]

    locations.each do |location|
      responses[location] = @carrier.find_rates(
                              location_fixtures[:beverly_hills],
                              location_fixtures[location],
                              package_fixtures.values_at(:chocolate_stuff)
                            )
    end

    prices_of = lambda { |sym| responses[sym].rates.map(&:price) }

    refute_equal prices_of.call(:fake_home_as_residential), prices_of.call(:fake_home_as_commercial)
    refute_equal prices_of.call(:fake_google_as_commercial), prices_of.call(:fake_google_as_residential)
  end

  def test_obtain_shipping_label
    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york_with_name],
      package_fixtures.values_at(:chocolate_stuff, :small_half_pound, :american_wii),
      :test => true,
      :reference_number => { :value => "FOO-123", :code => "PO" }
    )

    assert response.success?

    # All behavior specific to how a LabelResponse behaves in the
    # context of UPS label data is a matter for unit tests.  If
    # the data changes substantially, the create_shipment
    # ought to raise an exception and this test will fail.
    assert_instance_of ActiveShipping::LabelResponse, response
  end

  def test_obtain_shipping_label_without_dimensions
    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york_with_name],
      package_fixtures.values_at(:tshirts),
      :test => true
    )

    assert response.success?

    # All behavior specific to how a LabelResponse behaves in the
    # context of UPS label data is a matter for unit tests.  If
    # the data changes substantially, the create_shipment
    # ought to raise an exception and this test will fail.
    assert_instance_of ActiveShipping::LabelResponse, response
  end

  def test_obtain_international_shipping_label
    response = @carrier.create_shipment(
      location_fixtures[:new_york_with_name],
      location_fixtures[:ottawa_with_name],
      package_fixtures.values_at(:books),
      {
       :service_code => '07',
       :test => true,
      }
    )

    assert response.success?

    # All behavior specific to how a LabelResponse behaves in the
    # context of UPS label data is a matter for unit tests.  If
    # the data changes substantially, the create_shipment
    # ought to raise an exception and this test will fail.
    assert_instance_of ActiveShipping::LabelResponse, response
  end

  def test_delivery_date_estimates_within_zip
    today = Date.current

    response = @carrier.get_delivery_date_estimates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:new_york_with_name],
      package_fixtures.values_at(:books),
      today,
      {
        :test => true
      }
    )

    assert response.success?
    refute_empty response.delivery_estimates
    ground_delivery_estimate = response.delivery_estimates.select {|de| de.service_name == "UPS Ground"}.first
    assert_equal Date.parse(1.business_days.from_now.to_s), ground_delivery_estimate.date
  end

  def test_delivery_date_estimates_across_zips
    today = Date.current

    response = @carrier.get_delivery_date_estimates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:real_home_as_residential],
      package_fixtures.values_at(:books),
      today,
      {
        :test => true
      }
    )

    assert response.success?
    refute_empty response.delivery_estimates
    ground_delivery_estimate = response.delivery_estimates.select {|de| de.service_name == "UPS Ground"}.first
    assert_equal Date.parse(3.business_days.from_now.to_s), ground_delivery_estimate.date
    next_day_delivery_estimate = response.delivery_estimates.select {|de| de.service_name == "UPS Next Day Air"}.first
    assert_equal Date.parse(1.business_days.from_now.to_s), next_day_delivery_estimate.date
  end

  def test_rate_with_single_service
    response = @carrier.find_rates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:real_home_as_residential],
      package_fixtures.values_at(:books),
      {
        :service => UPS::DEFAULT_SERVICE_NAME_TO_CODE["UPS Ground"],
        :test => true
      }
    )

    assert response.success?
    refute response.rates.empty?
    assert_equal ["UPS Ground"], response.rates.map(&:service_name)
  end

  def test_delivery_date_estimates_intl
    today = Date.current
    response = @carrier.get_delivery_date_estimates(
      location_fixtures[:new_york_with_name],
      location_fixtures[:ottawa_with_name],
      package_fixtures.values_at(:books),
      pickup_date=today,
      {
        :test => true
      }
    )

    assert response.success?
    refute_empty response.delivery_estimates
    ww_express_estimate = response.delivery_estimates.select {|de| de.service_name == "UPS Worldwide Express"}.first
    assert_equal Date.parse(1.business_day.from_now.to_s), ww_express_estimate.date
  end

  def test_maximum_address_field_length
    assert_equal 35, @carrier.maximum_address_field_length
  end
end
