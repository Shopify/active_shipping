require 'test_helper'

class UPSTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @options   = fixtures(:ups).merge(:test => true)
    @carrier   = UPS.new(@options)
  end

  def test_tracking
    assert_nothing_raised do
      response = @carrier.find_tracking_info('1Z12345E0291980793')
    end
  end

  def test_tracking_with_bad_number
    assert_raises ResponseError do
      response = @carrier.find_tracking_info('1Z12345E029198079')
    end
  end

  def test_tracking_with_another_number
    assert_nothing_raised do
      response = @carrier.find_tracking_info('1Z12345E6692804405')
    end
  end

  def test_us_to_uk
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   @locations[:london],
                   @packages.values_at(:big_half_pound),
                   :test => true
                 )
    end
  end

  def test_puerto_rico
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills],
                   Location.new(:city => 'Ponce', :country => 'PR', :zip => '00733-1283'),
                   @packages.values_at(:big_half_pound),
                   :test => true
                 )
    end
  end

  def test_just_country_given
     if !@options[:origin_account]
       response = @carrier.find_rates(
                    @locations[:beverly_hills],
                    Location.new(:country => 'CA'),
                    Package.new(100, [5,10,20])
                  )
       assert_not_equal [], response.rates
     end
  end

   def test_just_country_given_with_origin_account_fails
     if @options[:origin_account]
       assert_raise ResponseError do
         response = @carrier.find_rates(
                    @locations[:beverly_hills],
                    Location.new(:country => 'CA'),
                    Package.new(100, [5,10,20])
                  )
       end
     end
  end

  def test_ottawa_to_beverly_hills
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills],
                   @packages.values_at(:book, :wii),
                   :test => true
                 )
    end

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates

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
    assert_equal @packages.values_at(:book, :wii), rate.packages

    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end

  def test_ottawa_to_us_fails_with_only_zip_and_origin_account
    if @options[:origin_account]
      assert_raises ResponseError do
        @carrier.find_rates(
          @locations[:ottawa],
          Location.new(:country => 'US', :zip => 90210),
          @packages.values_at(:book, :wii),
          :test => true
        )
      end
    end
  end

  def test_ottawa_to_us_fails_without_zip
    assert_raises ResponseError do
      @carrier.find_rates(
        @locations[:ottawa],
        Location.new(:country => 'US'),
        @packages.values_at(:book, :wii),
        :test => true
      )
    end
  end

  def test_ottawa_to_us_succeeds_with_only_zip
    if !@options[:origin_account]
      assert_nothing_raised do
        @carrier.find_rates(
          @locations[:ottawa],
          Location.new(:country => 'US', :zip => 90210),
          @packages.values_at(:book, :wii),
          :test => true
        )
      end
    end
  end

  def test_us_to_uk_with_different_pickup_types
    assert_nothing_raised do
      daily_response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:london],
        @packages.values_at(:book, :wii),
        :pickup_type => :daily_pickup,
        :test => true
      )
      one_time_response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:london],
        @packages.values_at(:book, :wii),
        :pickup_type => :one_time_pickup,
        :test => true
      )
      assert_not_equal daily_response.rates.map(&:price), one_time_response.rates.map(&:price)
    end
  end

  def test_bare_packages
    response = nil
    p = Package.new(0,0)
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:beverly_hills], # imperial (U.S. origin)
                   @locations[:ottawa],
                   p,
                   :test => true
                 )
    end
    assert response.success?, response.message
    assert_nothing_raised do
      response = @carrier.find_rates(
                   @locations[:ottawa],
                   @locations[:beverly_hills], # metric
                   p,
                   :test => true
                 )
    end
    assert response.success?, response.message
  end

  def test_different_rates_based_on_address_type
    responses = {}
    locations = [
      :fake_home_as_residential, :fake_home_as_commercial,
      :fake_google_as_residential, :fake_google_as_commercial
      ]

    locations.each do |location|
      responses[location] = @carrier.find_rates(
                              @locations[:beverly_hills],
                              @locations[location],
                              @packages.values_at(:chocolate_stuff)
                            )
    end

    prices_of = lambda {|sym| responses[sym].rates.map(&:price)}

    assert_not_equal prices_of.call(:fake_home_as_residential), prices_of.call(:fake_home_as_commercial)
    assert_not_equal prices_of.call(:fake_google_as_commercial), prices_of.call(:fake_google_as_residential)
  end

  def test_obtain_shipping_label
    response = nil

    # I want to provide some helpful information if this test fails.
    # Perhaps it is better to skip and warn than to make an *assertion*
    # about configuration?
    assert @options[:origin_name].present?, "test/fixtures.yml must have a valid ups/origin_name for this test to run"
    assert @options[:origin_account].present?, "test/fixtures.yml must have a valid ups/origin_account for this test to run"

    assert_nothing_raised do
      response = @carrier.obtain_shipping_labels(
        @locations[:beverly_hills],
        @locations[:new_york_with_name],
        @packages.values_at(:chocolate_stuff, :book, :american_wii),
        { :test => true,
          :reference_number => { :value => "FOO-123", :code => "PO" } }
      )
    end

    # All behavior specific to how a LabelResponse behaves in the
    # context of UPS label data is a matter for unit tests.  If
    # the data changes substantially, the obtain_shipping_labels
    # ought to raise an exception and this test will fail.
    assert_instance_of ActiveMerchant::Shipping::LabelResponse, response
  end

  def test_obtain_shipping_label_without_dimensions
    response = nil
    assert_nothing_raised do
      response = @carrier.obtain_shipping_labels(
        @locations[:beverly_hills],
        @locations[:new_york_with_name],
        @packages.values_at(:tshirts),
        { :test => true }
      )
    end
    assert_instance_of ActiveMerchant::Shipping::LabelResponse, response
  end

end
