require 'test_helper'

class AustraliaPostTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier    = AustraliaPost.new(api_key: '4d9dc0f0-dda0-012e-066f-000c29b44ac0')
    @sydney     = location_fixtures[:sydney]
    @melbourne  = location_fixtures[:melbourne]
    @ottawa     = location_fixtures[:ottawa]
  end

  def test_service_domestic_simple_request
    url = 'https://digitalapi.auspost.com.au/postage/parcel/domestic/service.json?from_postcode=2000&height=2&length=19&to_postcode=3108&weight=0.25&width=14'
    @carrier.expects(:commit).with(url).returns(json_fixture('australia_post/service_domestic'))
    @carrier.find_rates(@sydney, @melbourne, package_fixtures[:book])
  end

  def test_service_domestic_combined_request
    url_1 = 'https://digitalapi.auspost.com.au/postage/parcel/domestic/service.json?from_postcode=2000&height=2&length=19&to_postcode=3108&weight=0.25&width=14'
    url_2 = 'https://digitalapi.auspost.com.au/postage/parcel/domestic/service.json?from_postcode=2000&height=2.54&length=2.54&to_postcode=3108&weight=0.23&width=2.54'
    @carrier.expects(:commit).with(url_1).returns(json_fixture('australia_post/service_domestic'))
    @carrier.expects(:commit).with(url_2).returns(json_fixture('australia_post/service_domestic_2'))
    @carrier.find_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound))
  end

  def test_service_domestic_simple_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/service_domestic'))
    response = @carrier.find_rates(@sydney, @melbourne, package_fixtures[:book])
    prices = [2855, 1480, 1615, 1340]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['AUS_PARCEL_EXPRESS', 'AUS_PARCEL_EXPRESS_SATCHEL_3KG', 'AUS_PARCEL_REGULAR', 'AUS_PARCEL_REGULAR_SATCHEL_3KG']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Express Post', 'Express Post Medium (3Kg) Satchel', 'Parcel Post', 'Parcel Post Medium Satchel']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_service_domestic_combined_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/service_domestic'))
    @carrier.expects(:commit).returns(json_fixture('australia_post/service_domestic_2'))
    response = @carrier.find_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound))
    prices = [3875, 2360]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['AUS_PARCEL_EXPRESS', 'AUS_PARCEL_REGULAR']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Express Post', 'Parcel Post']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_service_international_simple_request
    url = 'https://digitalapi.auspost.com.au/postage/parcel/international/service.json?country_code=CA&weight=0.25'
    @carrier.expects(:commit).with(url).returns(json_fixture('australia_post/service_international'))
    @carrier.find_rates(@sydney, @ottawa, package_fixtures[:book])
  end

  def test_service_international_combined_request
    url_1 = 'https://digitalapi.auspost.com.au/postage/parcel/international/service.json?country_code=CA&weight=0.25'
    url_2 = 'https://digitalapi.auspost.com.au/postage/parcel/international/service.json?country_code=CA&weight=0.23'
    @carrier.expects(:commit).with(url_1).returns(json_fixture('australia_post/service_international'))
    @carrier.expects(:commit).with(url_2).returns(json_fixture('australia_post/service_international_2'))
    @carrier.find_rates(@sydney, @ottawa, package_fixtures.values_at(:book, :small_half_pound))
  end

  def test_service_international_simple_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/service_international'))
    response = @carrier.find_rates(@sydney, @ottawa, package_fixtures[:book])
    prices = [15417, 8917, 8417, 4680]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['INT_PARCEL_COR_OWN_PACKAGING', 'INT_PARCEL_EXP_OWN_PACKAGING', 'INT_PARCEL_STD_OWN_PACKAGING', 'INT_PARCEL_SEA_OWN_PACKAGING']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Courier', 'Express', 'Standard', 'Economy Sea']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_service_international_combined_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/service_international'))
    @carrier.expects(:commit).returns(json_fixture('australia_post/service_international_2'))
    response = @carrier.find_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound))
    prices = [17204, 15537, 8834]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['INT_PARCEL_EXP_OWN_PACKAGING', 'INT_PARCEL_STD_OWN_PACKAGING', 'INT_PARCEL_SEA_OWN_PACKAGING']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Express', 'Standard', 'Economy Sea']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_service_response_error
    error = assert_raises(ActiveShipping::ResponseError) do
      raise_error = ActiveShipping::ResponseError.new
      raise_error.expects(:response).returns(OpenStruct.new(body: json_fixture('australia_post/error_message')))
      @carrier.expects(:ssl_get).raises raise_error
      @carrier.find_rates(@sydney, @melbourne, package_fixtures[:book])
    end
    assert_equal 'Please enter From postcode.', error.response.message
  end

  def test_calculate_domestic_simple_request
    url = 'https://digitalapi.auspost.com.au/postage/parcel/domestic/calculate.json?from_postcode=2000&height=2&length=19&service_code=AUS_PARCEL_EXPRESS&to_postcode=3108&weight=0.25&width=14'
    @carrier.expects(:commit).with(url).returns(json_fixture('australia_post/calculate_domestic'))
    @carrier.calculate_rates(@sydney, @melbourne, package_fixtures[:book], 'AUS_PARCEL_EXPRESS')
  end

  def test_calculate_domestic_combined_request
    url_1 = 'https://digitalapi.auspost.com.au/postage/parcel/domestic/calculate.json?from_postcode=2000&height=2&length=19&service_code=AUS_PARCEL_EXPRESS&to_postcode=3108&weight=0.25&width=14'
    url_2 = 'https://digitalapi.auspost.com.au/postage/parcel/domestic/calculate.json?from_postcode=2000&height=2.54&length=2.54&service_code=AUS_PARCEL_EXPRESS&to_postcode=3108&weight=0.23&width=2.54'
    @carrier.expects(:commit).with(url_1).returns(json_fixture('australia_post/calculate_domestic'))
    @carrier.expects(:commit).with(url_2).returns(json_fixture('australia_post/calculate_domestic_2'))
    @carrier.calculate_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound), 'AUS_PARCEL_EXPRESS')
  end

  def test_calculate_domestic_simple_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/calculate_domestic'))
    response = @carrier.calculate_rates(@sydney, @melbourne, package_fixtures[:book], 'AUS_PARCEL_EXPRESS')
    prices = [1020]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['AUS_PARCEL_EXPRESS']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Express Post']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_calculate_domestic_combined_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/calculate_domestic'))
    @carrier.expects(:commit).returns(json_fixture('australia_post/calculate_domestic_2'))
    response = @carrier.calculate_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound), 'AUS_PARCEL_EXPRESS')
    prices = [2490]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['AUS_PARCEL_EXPRESS']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Express Post']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_calculate_international_simple_request
    url = 'https://digitalapi.auspost.com.au/postage/parcel/international/calculate.json?country_code=CA&service_code=INT_PARCEL_COR_OWN_PACKAGING&weight=0.25'
    @carrier.expects(:commit).with(url).returns(json_fixture('australia_post/calculate_international'))
    @carrier.calculate_rates(@sydney, @ottawa, package_fixtures[:book], 'INT_PARCEL_COR_OWN_PACKAGING')
  end

  def test_calculate_international_combined_request
    url_1 = 'https://digitalapi.auspost.com.au/postage/parcel/international/calculate.json?country_code=CA&service_code=INT_PARCEL_COR_OWN_PACKAGING&weight=0.25'
    url_2 = 'https://digitalapi.auspost.com.au/postage/parcel/international/calculate.json?country_code=CA&service_code=INT_PARCEL_COR_OWN_PACKAGING&weight=0.23'
    @carrier.expects(:commit).with(url_1).returns(json_fixture('australia_post/calculate_international'))
    @carrier.expects(:commit).with(url_2).returns(json_fixture('australia_post/calculate_international_2'))
    @carrier.calculate_rates(@sydney, @ottawa, package_fixtures.values_at(:book, :small_half_pound), 'INT_PARCEL_COR_OWN_PACKAGING')
  end

  def test_calculate_international_simple_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/calculate_international'))
    response = @carrier.calculate_rates(@sydney, @ottawa, package_fixtures[:book], 'INT_PARCEL_COR_OWN_PACKAGING')
    prices = [8736]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['INT_PARCEL_COR_OWN_PACKAGING']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Courier']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_calculate_international_combined_response
    @carrier.expects(:commit).returns(json_fixture('australia_post/calculate_international'))
    @carrier.expects(:commit).returns(json_fixture('australia_post/calculate_international_2'))
    response = @carrier.calculate_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound), 'INT_PARCEL_COR_OWN_PACKAGING')
    prices = [17472]
    assert_equal prices, response.rates.map(&:price)
    service_codes = ['INT_PARCEL_COR_OWN_PACKAGING']
    assert_equal service_codes, response.rates.map(&:service_code)
    service_names = ['Courier']
    assert_equal service_names, response.rates.map(&:service_name)
  end

  def test_calculate_response_error
    error = assert_raises(ActiveShipping::ResponseError) do
      raise_error = ActiveShipping::ResponseError.new
      raise_error.expects(:response).returns(OpenStruct.new(body: json_fixture('australia_post/error_message')))
      @carrier.expects(:ssl_get).raises raise_error
      @carrier.calculate_rates(@sydney, @melbourne, package_fixtures[:book], 'AUS_PARCEL_EXPRESS')
    end
    assert_equal 'Please enter From postcode.', error.response.message
  end

end
