require 'test_helper'

class RemoteKunakiTest < Test::Unit::TestCase
  def setup
    @packages   = TestFixtures.packages
    @locations  = TestFixtures.locations
    @carrier    = Kunaki.new
    @item1 = { :sku => 'XZZ1111111', :quantity => 2 }
    @item2 = { :sku => 'PXZZ111112', :quantity => 1 }
    @items = [@item1, @item2]
  end

  def test_successful_rates_request
    response = @carrier.find_rates(
                 @locations[:ottawa],
                 @locations[:beverly_hills],
                 @packages.values_at(:book, :wii),
                 :items => @items
               )

    assert response.success?
    assert_equal 4, response.rates.size
    assert_equal ["UPS 2nd Day Air", "UPS Ground", "UPS Next Day Air Saver", "USPS Priority Mail"], response.rates.collect(&:service_name).sort
  end

  def test_send_no_items
    assert_raise(ActiveMerchant::ResponseError) do
      begin
        response = @carrier.find_rates(
                     @locations[:ottawa],
                     @locations[:beverly_hills],
                     @packages.values_at(:book, :wii),
                     :items => []
                   )
      rescue ActiveMerchant::ResponseError => e
        assert_equal 500, e.response.code.to_i
        raise
      end
    end
  end
end
