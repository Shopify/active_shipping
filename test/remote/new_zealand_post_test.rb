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

  def test_multiple_packages_are_combined_correctly
    response_wii = @carrier.find_rates(@locations[:wellington],
                                       @locations[:wellington],
                                       @packages.values_at(:wii))
    response_book = @carrier.find_rates(@locations[:wellington],
                                        @locations[:wellington],
                                        @packages.values_at(:book))
    response_combined = @carrier.find_rates(@locations[:wellington],
                                            @locations[:wellington],
                                            @packages.values_at(:book, :wii))


    wii_rates, book_rates, combined_rates = {}, {}, {}
    response_wii.rate_estimates.each{ |r| wii_rates[r.service_code] = r.total_price }
    response_book.rate_estimates.each{ |r| book_rates[r.service_code] = r.total_price }
    response_combined.rate_estimates.each{ |r| combined_rates[r.service_code] = r.total_price }

    # every item in combined rates is made up of entries from the other two rates
    combined_rates.each do |service_code, total_price|
      assert_equal (wii_rates[service_code] + book_rates[service_code]), total_price
    end

    # the size of the elements common between wii and book rates is the size of the 
    # combined rates hash.
    assert_equal (wii_rates.keys & book_rates.keys).count, combined_rates.size

    #uncomment this test for visual display of combining rates
    #puts "\nWii:"
    #response_wii.rate_estimates.each{ |r| puts "\nTotal Price: #{r.total_price}\nService Name: #{r.service_name}" }
    #puts "\nBook:"
    #response_book.rate_estimates.each{ |r| puts "\nTotal Price: #{r.total_price}\nService Name: #{r.service_name}" }
    #puts "\nCombined"
    #response_combined.rate_estimates.each{ |r| puts "\nTotal Price: #{r.total_price}\nService Name: #{r.service_name}" }
  end
end
