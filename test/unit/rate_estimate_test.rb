require 'test_helper'

class RateEstimateTest < Minitest::Test
  def setup
    @origin      = {:address1 => "61A York St", :city => "Ottawa", :province => "ON", :country => "Canada", :postal_code => "K1N 5T2"}
    @destination = {:city => "Beverly Hills", :state => "CA", :country => "United States", :postal_code => "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], :description => "a box full of stuff", :value => 2500)]
    @carrier     = CanadaPost.new(login: 'test')
    @options     = {:currency => 'USD'}

    @rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options)
  end

  def test_date_for_nil_string
    assert_nil @rate_estimate.send(:date_for, nil)
  end

  def test_date_for_invalid_string_in_ruby_19
    assert_nil @rate_estimate.send(:date_for, "Up to 2 weeks") if RUBY_VERSION.include?('1.9')
  end

  def test_rate_estimate_converts_noniso_to_iso
    rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(:currency => 'UKL'))
    assert_equal 'GBP', rate_estimate.currency
  end

  def test_creating_an_estimate_with_an_invalid_currency_raises
    assert_raises(ActiveUtils::InvalidCurrencyCodeError) do
      RateEstimate.new(nil, nil, nil, nil, :currency => 'FAKE')
    end
  end

  def test_estimate_reference_is_set
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(estimate_reference: "somefakeref"))

    assert_equal "somefakeref", est.estimate_reference
  end
end
