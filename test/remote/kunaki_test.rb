require 'test_helper'

class RemoteKunakiTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Kunaki.new
    @item1 = { :sku => 'XZZ1111111', :quantity => 2 }
    @item2 = { :sku => 'PXZZ111112', :quantity => 1 }
    @items = [@item1, @item2]
  end

  def test_successful_rates_request
    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:beverly_hills],
                 package_fixtures.values_at(:book, :wii),
                 :items => @items
               )

    assert response.success?
    assert_equal 3, response.rates.size
    assert_equal ["UPS 2nd Day Air", "UPS Ground", "UPS Next Day Air Saver"], response.rates.collect(&:service_name).sort
  end

  def test_send_no_items
    assert_raises(ActiveUtils::ResponseError) do
      @carrier.find_rates(
        location_fixtures[:ottawa],
        location_fixtures[:beverly_hills],
        package_fixtures.values_at(:book, :wii),
        :items => []
      )
    end
  end
end
