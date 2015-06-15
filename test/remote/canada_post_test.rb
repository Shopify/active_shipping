require 'test_helper'

class RemoteCanadaPostTest < Minitest::Test
  include ActiveShipping::Test::Credentials

  def setup
    @carrier        = CanadaPost.new(credentials(:canada_post))
    @french_carrier = CanadaPost.new(credentials(:canada_post).merge(:french => true))

    @origin      = {:address1 => "61A York St", :city => "Ottawa", :province => "Ontario", :country => "Canada", :postal_code => "K1N 5T2"}
    @destination = {:city => "Beverly Hills", :state => "CA", :country => "United States", :postal_code => "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], :description => "a box full of stuff", :value => 25)]
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_find_rates_french
    rates = @french_carrier.find_rates(@origin, @destination, @line_items)
    assert_instance_of CanadaPost::CanadaPostRateResponse, rates
  end

  def test_postal_outlets_french
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
    rates = @carrier.find_rates(@origin, @destination, @line_items)

    rates.postal_outlets.each do |outlet|
      assert_instance_of CanadaPost::PostalOutlet, outlet
    end
  end

  def test_illegal_origin
    @origin = @destination

    assert_raises(ActiveShipping::ResponseError) do
      rates = @carrier.find_rates(@origin, @destination, @line_items)
      refute rates.success?
    end
  end

  def test_maximum_address_field_length
    assert_equal 44, @carrier.maximum_address_field_length
  end
end
