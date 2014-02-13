require 'test_helper'

class StampsTest < Test::Unit::TestCase
  def setup
    @packages   = TestFixtures.packages
    @locations  = TestFixtures.locations
    @line_items = TestFixtures.line_items1
    @carrier    = Stamps.new(fixtures(:stamps).merge(test: true))
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_account_info
    @account_info = @carrier.account_info

    assert_equal 'ActiveMerchant::Shipping::StampsAccountInfoResponse', @account_info.class.name
  end

  def test_zip_to_zip
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        Location.new(:zip => 40524),
        Location.new(:zip => 40515),
        Package.new(16, [12,6,2], units: :imperial)
      )
    end
  end

  def test_add_ons
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:new_york],
        @packages[:book],
        { add_ons: 'US-A-DC' }
      )
    end
  end

  def test_just_country_given
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        @locations[:beverly_hills],
        Location.new(:country => 'CZ'),
        Package.new(100, [5,10,20])
      )
    end
  end

  def test_us_to_canada
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:ottawa],
        @packages[:american_wii]
      )
    end

    assert_not_equal [], response.rates.length
  end

  def test_domestic_rates
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        @locations[:new_york],
        @locations[:beverly_hills],
        @packages[:american_wii]
      )
    end

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates

    rate = response.rates.first
    assert_equal 'Stamps', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates

    package = rate.packages.first
    assert_equal @packages[:american_wii].weight, package.weight
    assert_equal @packages[:american_wii].inches, package.inches
    assert_equal @packages[:american_wii].value, package.value
    assert_equal @packages[:american_wii].options[:units], package.options[:units]
  end

  def test_international_rates
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:ottawa],
        @packages[:book]
      )
    end

    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates

    rate = response.rates.first
    assert_equal 'Stamps', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates

    package = rate.packages.first
    assert_equal @packages[:book].weight, package.weight
    assert_equal @packages[:book].inches, package.inches
  end

  def test_us_to_us_possession
    response = nil
    assert_nothing_raised do
      response = @carrier.find_rates(
        @locations[:beverly_hills],
        @locations[:puerto_rico],
        @packages[:american_wii]
      )
    end

    assert_not_equal [], response.rates.length
  end

  def test_bare_packages_domestic
    response = nil
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0,0)
      )
    rescue ResponseError => e
      e.response
    end

    assert response.success?, response.message
  end

  def test_bare_packages_international
    response = nil
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:ottawa],
        Package.new(0,0)
      )
    rescue ResponseError => e
      e.response
    end

    assert response.success?, response.message
  end

  def test_first_class_packages_with_mail_type
    response = nil
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0,0),
        {
          service: 'US-FC',
          package_type: 'Package'
        }
      )
    rescue ResponseError => e
      e.response
    end

    assert response.success?, response.message
  end

  def test_first_class_packages_with_invalid_mail_type
    response = nil
    assert_raise ResponseError do
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0,0),
        {
          service: 'US-FC',
          package_type: 'Invalid'
        }
      )
    end
  end
end
