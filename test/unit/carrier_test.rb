require 'test_helper'

class CarrierTest < Minitest::Test
  class ExampleCarrier < Carrier
    cattr_reader :name
    @@name = "Example Carrier"
  end

  def setup
    @carrier = ExampleCarrier.new
  end

  def test_find_rates_not_implemented
    assert_raises NotImplementedError do
      @carrier.find_rates(nil, nil, nil)
    end
  end

  def test_create_shipment_not_implemented
    assert_raises NotImplementedError do
      @carrier.create_shipment(nil, nil, nil)
    end
  end

  def test_cancel_shipment_not_implemented
    assert_raises NotImplementedError do
      @carrier.cancel_shipment(nil)
    end
  end

  def test_find_tracking_info_not_implemented
    assert_raises NotImplementedError do
      @carrier.find_tracking_info(nil)
    end
  end

  def test_maximum_weight
    assert_equal Quantified::Mass.new(150, :pounds), @carrier.maximum_weight
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end

  def test_requirements_empty_array
    assert_equal [], @carrier.send(:requirements)
  end

  def test_timestamp_from_business_day_returns_nil_without_a_day
    assert_nil @carrier.send(:timestamp_from_business_day, nil)
  end

  def test_save_request
    request = Object.new
    assert_nil @carrier.last_request
    @carrier.send(:save_request, request)
    assert_equal request, @carrier.last_request
  end

  def test_timestamp_from_business_day_returns_two_days_in_the_future
    current = DateTime.new(2016, 7, 19) # Tuesday
    expected = DateTime.new(2016, 7, 21)

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 2)
    end
  end

  def test_timestamp_from_business_day_returns_two_days_in_the_future_over_a_weekend
    current = DateTime.new(2016, 7, 22) # Friday
    expected = DateTime.new(2016, 7, 26)

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 2)
    end
  end

  def test_timestamp_from_business_day_returns_fifteen_days_in_the_future
    current = DateTime.new(2016, 7, 6) # Wednesday
    expected = DateTime.new(2016, 7, 27) # includes 3 weekends

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 15)
    end
  end

  def test_timestamp_from_business_day_handles_saturday
    current = DateTime.new(2016, 7, 9) # Saturday
    expected = DateTime.new(2016, 7, 11)

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 1)
    end
  end

  def test_timestamp_from_business_day_handles_sunday
    current = DateTime.new(2016, 7, 10) # Sunday
    expected = DateTime.new(2016, 7, 11)

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 1)
    end
  end

  def test_timestamp_from_business_day_returns_datetime
    Timecop.freeze(DateTime.civil(2016, 7, 19)) do
      assert_equal DateTime, @carrier.send(:timestamp_from_business_day, 1).class
    end
  end

  def test_default_location
    result = Carrier.default_location

    assert_equal Location, result.class
    assert_equal ActiveUtils::Country.find("US"), result.country
    assert_equal "CA", result.state
    assert_equal "Beverly Hills", result.city
    assert_equal "455 N. Rexford Dr.", result.address1
    assert_equal "3rd Floor", result.address2
    assert_equal "90210", result.zip
    assert_equal "1-310-285-1013", result.phone
    assert_equal "1-310-275-8159", result.fax
  end
end
