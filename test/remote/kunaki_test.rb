require 'test_helper'

class RemoteKunakiTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Kunaki.new
    @item1 = { :sku => 'PX002LTGLS', :quantity => 2 }
    @item2 = { :sku => 'PX00MXGKAR', :quantity => 1 }
    @item3 = { :sku => 'PX00ZEDG6F', :quantity => 1 }
    @items = [@item1, @item2, @item3]
  end

  def test_successful_rates_request
    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:beverly_hills],
                 package_fixtures.values_at(:book, :wii),
                 :items => @items
               )

    assert response.success?
    assert_equal 4, response.rates.size
    assert_equal ["UPS 2nd Day Air", "UPS Ground", "UPS Next Day Air Saver", "USPS First Class Mail"], response.rates.collect(&:service_name).sort
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
