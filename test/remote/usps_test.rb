require 'test_helper'

class RemoteUSPSTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @usps_credentials = credentials(:usps)
    @carrier = USPS.new(@usps_credentials)
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_tracking
    response = @carrier.find_tracking_info('LN757696446US', test: false)
    assert response.success?, response.message
    assert_equal 13,response.shipment_events.size
    assert_equal 'DELIVERED', response.shipment_events.last.message
    assert_equal Time.parse('2015-11-30 13:02:00 UTC'), response.actual_delivery_date
  end

  def test_tracking_with_bad_number
    assert_raises(ResponseError) do
      @carrier.find_tracking_info('abc123xyz', test: false)
    end
  end

  def test_zip_to_zip
    response = @carrier.find_rates(
      Location.new(:zip => 40524),
      Location.new(:zip => 40515),
      Package.new(16, [12, 6, 2], :units => :imperial)
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_just_country_given
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      Location.new(:country => 'CZ'),
      Package.new(100, [5, 10, 20])
    )
    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_us_to_canada
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:ottawa],
      package_fixtures.values_at(:american_wii),
      :test => true
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_domestic_rates
    response = @carrier.find_rates(
      location_fixtures[:new_york],
      location_fixtures[:beverly_hills],
      package_fixtures.values_at(:book, :american_wii),
      :test => true
    )

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    refute response.rates.empty?

    rate = response.rates.first
    assert_equal 'USPS', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal package_fixtures.values_at(:book, :american_wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    refute_nil package_rate[:rate]

    other_than_two = response.rates.map(&:package_count).reject { |n| n == 2 }
    assert_equal [], other_than_two, "Some RateEstimates do not refer to the right number of packages (#{other_than_two.inspect})"
  end

  def test_international_rates
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:ottawa],
      package_fixtures.values_at(:book, :american_wii),
      :test => true
    )

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    refute response.rates.empty?

    rate = response.rates.first
    assert_equal 'USPS', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal package_fixtures.values_at(:book, :american_wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    refute_nil package_rate[:rate]

    other_than_two = response.rates.map(&:package_count).reject { |n| n == 2 }
    assert_equal [], other_than_two, "Some RateEstimates do not refer to the right number of packages (#{other_than_two.inspect})"
  end

  def test_us_to_us_possession
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills],
      location_fixtures[:puerto_rico],
      package_fixtures.values_at(:american_wii),
      :test => true
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_bare_packages_domestic
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills], # imperial (U.S. origin)
      location_fixtures[:new_york],
      Package.new(0, 0),
      :test => true
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_bare_packages_international
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills], # imperial (U.S. origin)
      location_fixtures[:ottawa],
      Package.new(0, 0),
      :test => true
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_first_class_packages_with_mail_type
    response = @carrier.find_rates(
      location_fixtures[:beverly_hills], # imperial (U.S. origin)
      location_fixtures[:new_york],
      Package.new(0, 0),

      :test => true,
      :service => :first_class,
      :first_class_mail_type => :parcel
    )

    assert response.success?, response.message
    refute response.rates.empty?
  end

  def test_first_class_packages_without_mail_type
    assert_raises(ResponseError, "Invalid First Class Mail Type.") do
      @carrier.find_rates(
        location_fixtures[:beverly_hills], # imperial (U.S. origin)
        location_fixtures[:new_york],
        Package.new(0, 0),

        :test => true,
        :service => :first_class
      )
    end
  end

  def test_first_class_packages_with_invalid_mail_type
    assert_raises(ResponseError, "Invalid First Class Mail Type.") do
      @carrier.find_rates(
        location_fixtures[:beverly_hills], # imperial (U.S. origin)
        location_fixtures[:new_york],
        Package.new(0, 0),

        :test => true,
        :service => :first_class,
        :first_class_mail_tpe => :invalid
      )
    end
  end

  def test_correct_login_passes_valid_credentials?
    assert USPS.new(@usps_credentials.merge(:test => true)).valid_credentials?
  end

  def test_wrong_login_fails_in_valid_credentials?
    refute USPS.new(:login => 'ABCDEFGHIJKL', :test => true).valid_credentials?
  end

  def test_blank_login_fails_in_valid_credentials?
    refute USPS.new(:login => '', :test => true).valid_credentials?
  end

  def test_nil_login_fails_in_valid_credentials?
    refute USPS.new(:login => nil, :test => true).valid_credentials?
  end

  def test_must_provide_login_creds_when_instantiating
    assert_raises ArgumentError do
      USPS.new(:test => true)
    end
  end

  # Uncomment and switch out SPECIAL_COUNTRIES with some other batch to see which
  # countries are currently working. Commented out here just because it's a lot of
  # hits to their server at once:

  # ALL_COUNTRIES = ActiveUtils::Country.const_get('COUNTRIES').map {|c| c[:alpha2]}
  # SPECIAL_COUNTRIES = USPS.const_get('COUNTRY_NAME_CONVERSIONS').keys.sort
  # NORMAL_COUNTRIES = (ALL_COUNTRIES - SPECIAL_COUNTRIES)
  #
  # SPECIAL_COUNTRIES.each do |code|
  #   unless ActiveUtils::Country.find(code).name == USPS.const_get('COUNTRY_NAME_CONVERSIONS')[code]
  #     define_method("test_country_#{code}") do
  #       response = nil
  #       begin
  #         response = @carrier.find_rates( location_fixtures[:beverly_hills],
  #                                         Location.new(:country => code),
  #                                         package_fixtures.values_at(:american_wii),
  #                                         :test => true)
  #       rescue Exception => e
  #         flunk(e.inspect + "\nrequest: " + @carrier.last_request)
  #       end
  #       assert_not_equal [], response.rates.length
  #     end
  #   end
  # end
end
