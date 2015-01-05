require 'test_helper'

class RemoteShipwireTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Shipwire.new(credentials(:shipwire))
    @item1 = { :sku => 'AF0001', :quantity => 2 }
    @item2 = { :sku => 'AF0002', :quantity => 1 }
    @items = [@item1, @item2]
  end

  def test_successful_domestic_rates_request_for_single_line_item
    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:beverly_hills],
                 package_fixtures.values_at(:book, :wii),
                 :items => [@item1],
                 :order_id => '#1000'
               )

    assert response.success?
    assert_equal 2, response.rates.size
    assert_equal Set['2D', 'GD'], Set.new(response.rates.map(&:service_code))
  end

  def test_successful_domestic_rates_request_for_multiple_line_items
    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:beverly_hills],
                 package_fixtures.values_at(:book, :wii),
                 :items => @items,
                 :order_id => '#1000'
               )

    assert response.success?
    assert_equal 2, response.rates.size
    assert_equal Set['2D', 'GD'], Set.new(response.rates.map(&:service_code))
  end

  def test_successful_international_rates_request_for_single_line_item
    # skip 'ActiveShipping::ResponseError: No shipping rates could be found for the destination address'
    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:london],
                 package_fixtures.values_at(:book, :wii),
                 :items => [@item1],
                 :order_id => '#1000'
               )

    assert response.success?
    assert_equal 3, response.rates.size
    assert_equal Set['1D', '2D', 'GD'], Set.new(response.rates.map(&:service_code))
  end

  def test_invalid_xml_raises_response_content_error
    @carrier.expects(:ssl_post).returns("")

    assert_raises ActiveShipping::ResponseContentError do
      @carrier.find_rates(
        location_fixtures[:ottawa],
        location_fixtures[:london],
        package_fixtures.values_at(:book, :wii),
        :items => @items,
        :order_id => '#1000'
      )
    end
  end

  def test_validate_credentials_with_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_validate_credentials_with_invalid_credentials
    shipwire = Shipwire.new(
      :login => 'your@email.com',
      :password => 'password'
    )
    refute shipwire.valid_credentials?
  end
end
