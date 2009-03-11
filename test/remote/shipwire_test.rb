require File.dirname(__FILE__) + '/../test_helper'

class RemoteShipwireTest < Test::Unit::TestCase
  
  def setup
    @packages   = TestFixtures.packages
    @locations  = TestFixtures.locations
    @carrier    = Shipwire.new(fixtures(:shipwire))
    @item1 = { :sku => 'AF0001', :quantity => 2 }
    @item2 = { :sku => 'AF0002', :quantity => 1 }
    @items = [@item1, @item2]
  end
  
  def test_successful_domestic_rates_request_for_single_line_item
    response = @carrier.find_rates(
                 @locations[:ottawa],
                 @locations[:beverly_hills],
                 @packages.values_at(:book, :wii),
                 :items => [@item1],
                 :order_id => '#1000'
               )
    
    assert response.success?    
    assert_equal 3, response.rates.size
    assert_equal ['1D', '2D', 'GD'], response.rates.collect(&:service_code).sort
  end
  
  def test_successful_domestic_rates_request_for_multiple_line_items
    response = @carrier.find_rates(
                 @locations[:ottawa],
                 @locations[:beverly_hills],
                 @packages.values_at(:book, :wii),
                 :items => @items,
                 :order_id => '#1000'
               )
    
    assert response.success?    
    assert_equal 3, response.rates.size
    assert_equal ['1D', '2D', 'GD'], response.rates.collect(&:service_code).sort
  end
  
  def test_successful_international_rates_request_for_single_line_item
    response = @carrier.find_rates(
                 @locations[:ottawa],
                 @locations[:london],
                 @packages.values_at(:book, :wii),
                 :items => [@item1],
                 :order_id => '#1000'
               )
    
    assert response.success?    
    assert_equal 1, response.rates.size
    assert_equal ['INTL'], response.rates.collect(&:service_code)
  end
  
  def test_invalid_credentials
    shipwire = Shipwire.new(
      :login => 'your@email.com',
      :password => 'password'
    )
    
    begin
      assert_raises(ActiveMerchant::Shipping::ResponseError) do
        shipwire.find_rates(
          @locations[:ottawa],
          @locations[:beverly_hills],
          @packages.values_at(:book, :wii),
          :items => @items,
          :order_id => '#1000'
        )
      end
    rescue ResponseError => e
      assert_equal "Could not verify e-mail/password combination", response.message
    end
  end
  
end