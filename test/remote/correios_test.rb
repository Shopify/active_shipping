require 'test_helper'

class RemoteCorreiosTest < Minitest::Test
  include ActiveShipping::Test::Fixtures
  include ActiveShipping::Test::Credentials

  def setup
    @carrier = Correios.new

    @saopaulo = Location.new(:zip => "01415000")
    @riodejaneiro = Location.new(:zip => "22210030")
    @invalid_city = Location.new(:zip => "invalid")

    @book = Package.new(250, [14, 19, 2])
    @poster = Package.new(100, [93, 15], :cylinder => true)

    @response_clothes = xml_fixture('correios/clothes_response')
    @response_shoes = xml_fixture('correios/shoes_response')
    @response_book_success = xml_fixture('correios/book_response')
    @response_poster_success = xml_fixture('correios/poster_response')
    @response_book_invalid = xml_fixture('correios/book_response_invalid')
  end

  def test_book_request
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book])

    assert response.is_a?(RateResponse)
    assert response.rates.first.is_a?(RateEstimate)
    assert response.success?
    assert_equal 1, response.params["responses"].size
    assert_equal 2, response.rates.size
    assert_equal 1, response.raw_responses.size
  end

  def test_poster_and_book_request
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book, @poster])

    assert response.is_a?(RateResponse)
    assert response.rates.first.is_a?(RateEstimate)
    assert response.success?
    assert_equal 2, response.params["responses"].size
    assert_equal 2, response.rates.size
    assert_equal 2, response.raw_responses.size
  end

  def test_book_request_with_specific_services
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book], :services => [41106, 40010, 40215])

    assert response.is_a?(RateResponse)
    assert response.rates.first.is_a?(RateEstimate)
    assert response.success?
    assert_equal 1, response.params["responses"].size
    assert_equal 3, response.rates.size
    assert_equal 1, response.raw_responses.size
  end

  def test_response_prices
    response = @carrier.find_rates(@saopaulo, @riodejaneiro, [@book, @poster])
    response_book= @carrier.find_rates(@saopaulo, @riodejaneiro, [@book])
    response_poster = @carrier.find_rates(@saopaulo, @riodejaneiro, [@poster])

    book_price = response_book.rates.sum(&:price)
    poster_price = response_poster.rates.sum(&:price)
    total_price = response.rates.sum(&:price)

    assert total_price == (book_price + poster_price)
  end

  def test_invalid_zip
    assert_raises(ActiveShipping::ResponseError) do
      @carrier.find_rates(@saopaulo, @invalid_city, [@book])
    end
  rescue => error
    assert_equal ActiveShipping::ResponseError, error.class
    assert_equal RateResponse, error.response
    assert_not error.message.empty?
    assert error.response.raw_responses.any?
    assert_equal Hash.new, error.response.params
  end

end
