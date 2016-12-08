require 'test_helper'

class KunakiTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier   = Kunaki.new
    @items = [{ :sku => 'AF0001', :quantity => 1 }, { :sku => 'AF0002', :quantity => 2 }]
  end

  def test_unsuccessful_rate_request
    @carrier.expects(:ssl_post).returns(xml_fixture('kunaki/unsuccessful_rates_response'))

    assert_raises(ResponseError) do
      begin
        @carrier.find_rates(
          location_fixtures[:ottawa],
          location_fixtures[:beverly_hills],
          package_fixtures.values_at(:book, :wii),
          :items => @items
        )
      rescue ResponseError => e
        assert_equal "Request contains invalid XML syntax", e.response.message
        assert_equal "100", e.response.params["ErrorCode"]
        raise
      end
    end
  end

  def test_successfully_get_rates
    @carrier.expects(:ssl_post).returns(xml_fixture('kunaki/successful_rates_response'))

    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:london],
                 package_fixtures.values_at(:book, :wii),
                 :items => @items
               )

    assert response.success?

    assert_equal 4, response.rates.size

    assert rate = response.rates.first
    assert_equal "USPS Priority Mail", rate.service_name
    assert_nil rate.service_code
    assert_equal "USPS", rate.carrier
    assert_equal 800, rate.total_price
    assert_equal ["UPS 2nd Day Air", "UPS Ground", "UPS Next Day Air Saver", "USPS Priority Mail"], response.rates.collect(&:service_name).sort
    assert_equal [800, 1234, 2186, 3605], response.rates.collect(&:total_price).sort
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end
end
