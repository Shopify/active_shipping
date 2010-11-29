require 'test_helper'

class NewZealandPostTest < Test::Unit::TestCase

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = NewZealandPost.new(fixtures(:new_zealand_post).merge(:test => true))
  end
    
  def test_valid_credentials
    assert @carrier.valid_credentials?
  end
    
  def test_successful_rates_request
    response = @carrier.find_rates(@locations[:wellington],
                                   @locations[:wellington],
                                   @packages.values_at(:book, :wii))

    assert response.is_a?(RateResponse)
    assert response.success?
    assert response.rates.any?
    assert response.rates.first.is_a?(RateEstimate)
    assert_equal "dummy", response
  end

  def test_failure_rates_request
    begin
      @carrier.find_rates(
                   @locations[:wellington],
                   @locations[:wellington],
                   @packages[:shipping_container])
                   
      flunk "expected an ActiveMerchant::Shipping::ResponseError to be raised"
    rescue ActiveMerchant::Shipping::ResponseError => e
      assert_equal 'length Value is too large', e.message
    end
  end
end
