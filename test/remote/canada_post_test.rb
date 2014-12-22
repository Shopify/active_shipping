require 'test_helper'

class CanadaPostTest < Test::Unit::TestCase
  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    login = fixtures(:canada_post)

    @request  = xml_fixture('canadapost/example_request')
    @response_with_postal_outlets = xml_fixture('canadapost/example_response_with_postal_outlet')
    @response_with_postal_outlets_french = xml_fixture('canadapost/example_response_with_postal_outlet_french')
    @carrier   = CanadaPost.new(login)
    @french_carrier = CanadaPost.new(login.merge(:french => true))

    @origin      = {:address1 => "61A York St", :city => "Ottawa", :province => "Ontario", :country => "Canada", :postal_code => "K1N 5T2"}
    @destination = {:city => "Beverly Hills", :state => "CA", :country => "United States", :postal_code => "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], :description => "a box full of stuff", :value => 25)]
  end

  def test_valid_credentials
    @carrier.expects(:build_rate_request).returns(@request)
    assert @carrier.valid_credentials?
  end

  def test_find_rates_french
    rates = @french_carrier.find_rates(@origin, @destination, @line_items)
    assert_instance_of CanadaPost::CanadaPostRateResponse, rates
  end

  def test_postal_outlets_french
    @french_carrier.expects(:ssl_post).returns(@response_with_postal_outlets)
    rates = @french_carrier.find_rates(@origin, @destination, @line_items)

    rates.postal_outlets.each do |outlet|
      assert_instance_of CanadaPost::PostalOutlet, outlet
    end
  end

  def test_find_rates
    rates = @carrier.find_rates(@origin, @destination, @line_items)
    assert_instance_of CanadaPost::CanadaPostRateResponse, rates
  end

  def test_postal_outlets
    @carrier.expects(:ssl_post).returns(@response_with_postal_outlets_french)
    rates = @carrier.find_rates(@origin, @destination, @line_items)

    rates.postal_outlets.each do |outlet|
      assert_instance_of CanadaPost::PostalOutlet, outlet
    end
  end

  def test_illegal_origin
    @origin = @destination

    assert_raise ActiveShipping::ResponseError do
      rates = @carrier.find_rates(@origin, @destination, @line_items)
      assert !rates.success?
    end
  end
end
