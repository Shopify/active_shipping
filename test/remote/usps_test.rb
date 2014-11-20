require 'test_helper'

class USPSTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = USPS.new(fixtures(:usps))
  end

  def test_tracking
    skip '<#<ActiveMerchant::Shipping::ResponseError: There is no record of that mail item. If it was mailed recently, it may not yet be tracked. Please try again later.>>.'
    assert_nothing_raised do
      @carrier.find_tracking_info('EJ958083578US', :test => true)
    end
  end

  def test_tracking_with_bad_number
    assert_raises ResponseError do
      @carrier.find_tracking_info('abc123xyz')
    end
  end

  def test_zip_to_zip
    assert_nothing_raised do
      @carrier.find_rates(
        Location.new(:zip => 40524),
        Location.new(:zip => 40515),
        Package.new(16, [12, 6, 2], :units => :imperial)
      )
    end
  end

  def test_just_country_given
    assert_nothing_raised do
      @carrier.find_rates(
        @locations[:beverly_hills],
        Location.new(:country => 'CZ'),
        Package.new(100, [5, 10, 20])
      )
    end
  end

  def test_us_to_canada
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:ottawa],
                   @packages.values_at(:american_wii),
                   :test => true
                 )
      assert_not_equal [], response.rates.length
    end
  end

  def test_domestic_rates
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:new_york],
                   @locations[:beverly_hills],
                   @packages.values_at(:book, :american_wii),
                   :test => true
                 )
    end
    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates

    rate = response.rates.first
    assert_equal 'USPS', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :american_wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_not_nil package_rate[:rate]

    other_than_two = response.rates.map(&:package_count).reject { |n| n == 2 }
    assert_equal [], other_than_two, "Some RateEstimates do not refer to the right number of packages (#{other_than_two.inspect})"
  end

  def test_international_rates
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:ottawa],
                   @packages.values_at(:book, :american_wii),
                   :test => true
                 )
    end

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates

    rate = response.rates.first
    assert_equal 'USPS', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :american_wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_not_nil package_rate[:rate]

    other_than_two = response.rates.map(&:package_count).reject { |n| n == 2 }
    assert_equal [], other_than_two, "Some RateEstimates do not refer to the right number of packages (#{other_than_two.inspect})"
  end

  def test_us_to_us_possession
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:puerto_rico],
                   @packages.values_at(:american_wii),
                   :test => true
                 )
      assert_not_equal [], response.rates.length
    end
  end

  def test_bare_packages_domestic
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0, 0),
        :test => true
      )
    rescue ResponseError => e
      e.response
    end
    assert response.success?, response.message
  end

  def test_bare_packages_international
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:ottawa],
        Package.new(0, 0),
        :test => true
      )
    rescue ResponseError => e
      e.response
    end
    assert response.success?, response.message
  end

  def test_first_class_packages_with_mail_type
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0, 0),

        :test => true,
        :service => :first_class,
        :first_class_mail_type => :parcel

      )
    rescue ResponseError => e
      e.response
    end
    assert response.success?, response.message
  end

  def test_first_class_packages_without_mail_type
    @carrier.find_rates(
      @locations[:beverly_hills], # imperial (U.S. origin)
      @locations[:new_york],
      Package.new(0, 0),

      :test => true,
      :service => :first_class

    )
  rescue ResponseError => e
    assert_equal "Invalid First Class Mail Type.", e.message
  end

  def test_first_class_packages_with_invalid_mail_type
    @carrier.find_rates(
      @locations[:beverly_hills], # imperial (U.S. origin)
      @locations[:new_york],
      Package.new(0, 0),

      :test => true,
      :service => :first_class,
      :first_class_mail_tpe => :invalid

    )
  rescue ResponseError => e
    assert_equal "Invalid First Class Mail Type.", e.message
  end

  def test_valid_credentials
    assert USPS.new(fixtures(:usps).merge(:test => true)).valid_credentials?
  end

  def test_must_provide_login_creds_when_instantiating
    assert_raises ArgumentError do
      USPS.new(:test => true)
    end
  end

  # Uncomment and switch out SPECIAL_COUNTRIES with some other batch to see which
  # countries are currently working. Commented out here just because it's a lot of
  # hits to their server at once:

  # ALL_COUNTRIES = ActiveMerchant::Country.const_get('COUNTRIES').map {|c| c[:alpha2]}
  # SPECIAL_COUNTRIES = USPS.const_get('COUNTRY_NAME_CONVERSIONS').keys.sort
  # NORMAL_COUNTRIES = (ALL_COUNTRIES - SPECIAL_COUNTRIES)
  #
  # SPECIAL_COUNTRIES.each do |code|
  #   unless ActiveMerchant::Country.find(code).name == USPS.const_get('COUNTRY_NAME_CONVERSIONS')[code]
  #     define_method("test_country_#{code}") do
  #       response = nil
  #       begin
  #         response = @carrier.find_rates( @locations[:beverly_hills],
  #                                         Location.new(:country => code),
  #                                         @packages.values_at(:american_wii),
  #                                         :test => true)
  #       rescue Exception => e
  #         flunk(e.inspect + "\nrequest: " + @carrier.last_request)
  #       end
  #       assert_not_equal [], response.rates.length
  #     end
  #   end
  # end
end
