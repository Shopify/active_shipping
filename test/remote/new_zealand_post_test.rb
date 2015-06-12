require 'test_helper'

class RemoteNewZealandPostTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier   = NewZealandPost.new(credentials(:new_zealand_post).merge(:test => true))
    @wellington = location_fixtures[:wellington]
    @auckland = location_fixtures[:auckland]
    @ottawa = location_fixtures[:ottawa]
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_domestic_response
    response = @carrier.find_rates(@wellington, @auckland, package_fixtures[:wii])

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 1, response.params["responses"].size
    assert_equal 1, response.request.size
    assert_equal 1, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_domestic_combined_response
    response = @carrier.find_rates(@wellington, @auckland, package_fixtures.values_at(:book, :small_half_pound))

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
    assert_equal 2, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_domestic_failed_response_raises
    skip 'ActiveShipping::ResponseError expected but nothing was raised.'
    assert_raises ActiveShipping::ResponseError do
      @carrier.find_rates(@wellington, @auckland, package_fixtures[:shipping_container])
    end
  end

  def test_domestic_failed_response_message
    skip 'Expected /Length can only be between 0 and 150cm/ to match "success".'
    error = @carrier.find_rates(@wellington, @auckland, package_fixtures[:shipping_container]) rescue $!
    assert_match /Length can only be between 0 and 150cm/, error.message
  end

  def test_domestic_combined_response_prices
    response_book = @carrier.find_rates(@wellington, @auckland, package_fixtures[:book])
    response_small_half_pound = @carrier.find_rates(@wellington, @auckland, package_fixtures[:small_half_pound])
    response_combined = @carrier.find_rates(@wellington, @auckland, package_fixtures.values_at(:book, :small_half_pound))

    assert response_combined.is_a?(RateResponse)
    assert response_combined.success?
    assert response_book.rates.first.is_a?(RateEstimate)
    assert response_small_half_pound.rates.first.is_a?(RateEstimate)
    assert response_combined.rates.first.is_a?(RateEstimate)

    sum_book_prices = response_book.rates.sum(&:price)
    sum_small_half_pound_prices = response_small_half_pound.rates.sum(&:price)
    sum_combined_prices = response_combined.rates.sum(&:price)

    assert sum_book_prices > 0
    assert sum_small_half_pound_prices > 0
    assert sum_combined_prices > 0
    assert sum_combined_prices <= sum_book_prices + sum_small_half_pound_prices

    # uncomment this test for visual display of combining rates
    # puts "\nBook:"
    # response_wii.rate_estimates.each{ |r| puts "\nTotal Price: #{r.total_price}\nService Name: #{r.service_name} (#{r.service_code})" }
    # puts "\Small half pound:"
    # response_book.rate_estimates.each{ |r| puts "\nTotal Price: #{r.total_price}\nService Name: #{r.service_name} (#{r.service_code})" }
    # puts "\nCombined"
    # response_combined.rate_estimates.each{ |r| puts "\nTotal Price: #{r.total_price}\nService Name: #{r.service_name} (#{r.service_code})" }
  end

  def test_international_book_response
    response = @carrier.find_rates(@wellington, @ottawa, package_fixtures[:book])
    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
  end

  def test_international_poster_response
    response = @carrier.find_rates(@wellington, @ottawa, package_fixtures[:poster])
    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
  end

  def test_international_combined_response
    response = @carrier.find_rates(@wellington, @ottawa, package_fixtures.values_at(:book, :poster))
    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.request.size
    assert_equal 2, response.raw_responses.size
    assert response.request.first.size > 0
    assert response.params["responses"].first.size > 0
    assert response.raw_responses.first.size > 0
  end

  def test_international_shipping_container_response
    response = @carrier.find_rates(@wellington, @ottawa, package_fixtures[:shipping_container])
    assert response.is_a?(RateResponse)
    assert response.success?
    assert_equal 0, response.rates.size
  end

  def test_international_gold_bar_response
    response = @carrier.find_rates(@wellington, @ottawa, package_fixtures[:largest_gold_bar])
    assert response.is_a?(RateResponse)
    assert response.success?
    assert_equal 0, response.rates.size
  end

  def test_international_empty_package_response
    response = @carrier.find_rates(@wellington, @ottawa, package_fixtures[:just_zero_weight])
    assert response.is_a?(RateResponse)
    assert response.success?
    assert_equal 0, response.rates.size
  end

  def test_international_just_country_given
    response = @carrier.find_rates(@wellington, Location.new(:country => 'CZ'), package_fixtures[:book])
    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.size > 0
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end
end
