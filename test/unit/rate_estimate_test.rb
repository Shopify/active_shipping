require 'test_helper'

class RateEstimateTest < ActiveSupport::TestCase
  setup do
    @origin      = {address1: "61A York St", city: "Ottawa", province: "ON", country: "Canada", postal_code: "K1N 5T2"}
    @destination = {city: "Beverly Hills", state: "CA", country: "United States", postal_code: "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], description: "a box full of stuff", value: 2500)]
    @carrier     = CanadaPost.new(login: 'test')
    @options     = {currency: 'USD', delivery_range: [DateTime.parse("Fri 01 Jul 2016"), DateTime.parse("Sun 03 Jul 2016")]}

    @rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options)
  end

  test "#initialize accepts phone_required option field" do
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(phone_required: true))
    assert_equal true, est.phone_required

    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(phone_required: nil))
    assert_equal false, est.phone_required

    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(phone_required: false))
    assert_equal false, est.phone_required
  end

  test "#initialize accepts description option field" do
    rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(description: "It's free!"))
    assert_equal "It's free!", rate_estimate.description
  end

  test "#initialize converts noniso currency to iso" do
    rate_estimate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(currency: 'UKL'))
    assert_equal 'GBP', rate_estimate.currency
  end

  test "#initialize raises if invalid currency code" do
    assert_raises(ActiveUtils::InvalidCurrencyCodeError) do
      RateEstimate.new(nil, nil, nil, nil, currency: 'FAKE')
    end
  end

  test "#initialize accepts estimate_reference option field" do
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(estimate_reference: "somefakeref"))

    assert_equal "somefakeref", est.estimate_reference
  end

  test "#initialize accepts compare_price option field" do
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(compare_price: 10.0))
    assert_equal 1000, est.compare_price
  end

  test "#initialize accepts delivery_category option field" do
    est = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(delivery_category: "local_delivery"))

    assert_equal "local_delivery", est.delivery_category
  end

  test "#initialize accepts charge_items option field" do
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

  test "delivery_date is pulled from the later date of the delivery_range" do
    assert_equal [DateTime.parse("Fri 01 Jul 2016"), DateTime.parse("Sun 03 Jul 2016")], @rate_estimate.delivery_range
    assert_equal DateTime.parse("Sun 03 Jul 2016"), @rate_estimate.delivery_date
  end

  test "#initialize accepts messages option field" do
    rate = RateEstimate.new(@origin, @destination, @carrier, @service_name, @options.merge(messages: ["warning"]))
    assert_equal ["warning"], rate.messages
  end

  test "#date_for returns nil when given nil string" do
    assert_nil @rate_estimate.send(:date_for, nil)
  end
end
