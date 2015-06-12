require 'test_helper'

class RemoteCorreiosTest < Minitest::Test

  def setup
    @carrier = Correios.new

    @saopaulo = Location.new(:zip => "01415000")
    @riodejaneiro = Location.new(:zip => "22210030")
    @invalid_city = Location.new(:zip => "invalid")

    @book = Package.new(250, [14, 19, 2])
    @invalid_book = Package.new(9999999999999, [14, 19, 2])
    @poster = Package.new(100, [93, 15], :cylinder => true)
  end

  def test_book_request
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book])

    assert response.is_a?(RateResponse)
    assert response.rates.first.is_a?(RateEstimate)
    assert response.success?
    assert_equal 1, response.params["responses"].size
    assert_equal 2, response.rates.size
    assert_equal 1, response.raw_responses.size
  rescue ActiveUtils::ConnectionError
    skip("This API is unreliable and often times out.")
  end

  def test_poster_and_book_request
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book, @poster])

    assert response.is_a?(RateResponse)
    assert response.rates.first.is_a?(RateEstimate)
    assert response.success?
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.rates.size
    assert_equal 2, response.raw_responses.size
  rescue ActiveUtils::ConnectionError
    skip("This API is unreliable and often times out.")
  end

  def test_book_request_with_specific_services
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book], :services => [41106, 40010, 40215])

    assert response.is_a?(RateResponse)
    assert response.rates.first.is_a?(RateEstimate)
    assert response.success?
    assert_equal 1, response.params["responses"].size
    assert_equal 3, response.rates.size
    assert_equal 1, response.raw_responses.size
  rescue ActiveUtils::ConnectionError
    skip("This API is unreliable and often times out.")
  end

  def test_response_prices
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book, @poster])
    response_book= @carrier.find_rates(@saopaulo, @riodejaneiro, [@book])
    response_poster = @carrier.find_rates(@saopaulo, @riodejaneiro, [@poster])

    book_price = response_book.rates.sum(&:price)
    poster_price = response_poster.rates.sum(&:price)
    total_price = response.rates.sum(&:price)

    assert total_price == book_price + poster_price
  rescue ActiveUtils::ConnectionError
    skip("This API is unreliable and often times out.")
  end

  def test_invalid_zip
    error = assert_raises(ActiveShipping::ResponseError) do
      begin
        @carrier.find_rates(@saopaulo, @invalid_city, [@book])
      rescue ActiveUtils::ConnectionError
        skip("This API is unreliable and often times out.")
      end
    end

    assert_kind_of RateResponse, error.response
    refute error.message.empty?
    assert error.response.raw_responses.any?
    assert_equal Hash.new, error.response.params
  end

  def test_valid_book_and_invalid_book
    error = assert_raises(ActiveShipping::ResponseError) do
      begin
        @carrier.find_rates(@saopaulo, @riodejaneiro, [@book, @invalid_book])
      rescue ActiveUtils::ConnectionError
        skip("This API is unreliable and often times out.")
      end
    end

    assert_kind_of RateResponse, error.response
    refute error.message.empty?
    assert error.response.raw_responses.any?
    assert_equal Hash.new, error.response.params
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end
end
