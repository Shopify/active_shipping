require 'test_helper'

class RemoteAustraliaPostTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier    = AustraliaPost.new(credentials(:australia_post))
    @sydney     = location_fixtures[:sydney]
    @melbourne  = location_fixtures[:melbourne]
    @ottawa     = location_fixtures[:ottawa]
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_service_domestic_simple_request
    response = @carrier.find_rates(@sydney, @melbourne, package_fixtures[:wii])

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
  end

  def test_service_domestic_combined_request
    response = @carrier.find_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound))

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
  end

  def test_service_international_simple_request
    response = @carrier.find_rates(@sydney, @ottawa, package_fixtures[:wii])

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
  end

  def test_service_domestic_combined_request
    response = @carrier.find_rates(@sydney, @ottawa, package_fixtures.values_at(:book, :small_half_pound))

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
  end

  def test_service_domestic_response_error
    error = assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_rates(@sydney, @melbourne, package_fixtures[:largest_gold_bar])
    end

    assert_equal 'The maximum weight of a parcel is 22 kg.', error.message
  end

  def test_service_international_response_error
    error = assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_rates(@sydney, @ottawa, package_fixtures[:largest_gold_bar])
    end

    assert_equal 'The maximum weight of a parcel is 20 kg.', error.message
  end

  def test_calculate_domestic_simple_request
    response = @carrier.calculate_rates(@sydney, @melbourne, package_fixtures[:wii], 'AUS_PARCEL_EXPRESS')

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
  end

  def test_calculate_domestic_combined_request
    response = @carrier.calculate_rates(@sydney, @melbourne, package_fixtures.values_at(:book, :small_half_pound), 'AUS_PARCEL_EXPRESS')

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
  end

  def test_calculate_international_simple_request
    response = @carrier.calculate_rates(@sydney, @ottawa, package_fixtures[:wii], 'INT_PARCEL_COR_OWN_PACKAGING')

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
  end

  def test_calculate_domestic_combined_request
    response = @carrier.calculate_rates(@sydney, @ottawa, package_fixtures.values_at(:book, :small_half_pound), 'INT_PARCEL_COR_OWN_PACKAGING')

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
  end

  def test_calculate_domestic_response_error
    error = assert_raises(ActiveShipping::ResponseError) do
      @carrier.calculate_rates(@sydney, @melbourne, package_fixtures[:wii], 'INT_PARCEL_COR_OWN_PACKAGING')
    end

    assert_equal 'Please enter a valid Service code.', error.message
  end

  def test_calculate_international_response_error
    error = assert_raises(ActiveShipping::ResponseError) do
      @carrier.calculate_rates(@sydney, @ottawa, package_fixtures[:wii], 'AUS_PARCEL_EXPRESS')
    end

    assert_equal 'Please enter a valid Service code.', error.message
  end

end
