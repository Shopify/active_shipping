require 'test_helper'

class RateEstimateTest < Minitest::Test
  def setup
    @origin      = {address1: "61A York St", city: "Ottawa", province: "ON", country: "Canada", postal_code: "K1N 5T2"}
    @destination = {city: "Beverly Hills", state: "CA", country: "United States", postal_code: "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], description: "a box full of stuff", value: 2500)]
    @carrier     = CanadaPost.new(login: 'test')
    @options     = {currency: 'USD', delivery_range: [DateTime.parse("Fri 01 Jul 2016"), DateTime.parse("Sun 03 Jul 2016")]}

    @rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options)
  end

  def test_date_for_nil_string
    assert_nil @rate_estimate.send(:date_for, nil)
  end

  def test_phone_required
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(phone_required: true))
    assert_equal true, est.phone_required

    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(phone_required: nil))
    assert_equal false, est.phone_required

    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(phone_required: false))
    assert_equal false, est.phone_required
  end

  def test_accepts_description_field
    rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(description: "It's free!"))
    assert_equal "It's free!", rate_estimate.description
  end

  def test_date_for_invalid_string_in_ruby_19
    assert_nil @rate_estimate.send(:date_for, "Up to 2 weeks") if RUBY_VERSION.include?('1.9')
  end

  def test_rate_estimate_converts_noniso_to_iso
    rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(currency: 'UKL'))
    assert_equal 'GBP', rate_estimate.currency
  end

  def test_creating_an_estimate_with_an_invalid_currency_raises
    assert_raises(ActiveUtils::InvalidCurrencyCodeError) do
      RateEstimate.new(nil, nil, nil, nil, currency: 'FAKE')
    end
  end

  def test_estimate_reference_is_set
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(estimate_reference: "somefakeref"))

    assert_equal "somefakeref", est.estimate_reference
  end

  def test_compare_price_is_set
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(compare_price: 10.0))
    assert_equal 1000, est.compare_price
  end

  def test_delivery_category_is_set
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(delivery_category: "local_delivery"))

    assert_equal "local_delivery", est.delivery_category
  end

  def test_charge_items_is_set
    charge_items = [
      {
        group: "base_charge",
        code: 'label',
        name: "USPS Priority Mail label",
        description: "USPS Priority Mail label to New York, NY, US",
        amount: 14.64
      },
      {
        group: "included_option",
        code: 'tracking',
        name: "Tracking",
        description: "Free tracking",
        amount: 0
      }
    ]
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(charge_items: charge_items))

    assert_equal charge_items, est.charge_items
  end

  def test_delivery_date_pulls_from_delivery_range
    assert_equal [DateTime.parse("Fri 01 Jul 2016"), DateTime.parse("Sun 03 Jul 2016")], @rate_estimate.delivery_range
    assert_equal DateTime.parse("Sun 03 Jul 2016"), @rate_estimate.delivery_date
  end
end
