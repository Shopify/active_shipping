require 'test_helper'

class CarrierTest < ActiveSupport::TestCase
  class ExampleCarrier < Carrier
    cattr_reader :name
    @@name = "Example Carrier"
  end

  setup do
    @carrier = ExampleCarrier.new
  end

  test "#find_rates is not implemented" do
    assert_raises NotImplementedError do
      @carrier.find_rates(nil, nil, nil)
    end
  end

  test "#create_shipment is not implemented" do
    assert_raises NotImplementedError do
      @carrier.create_shipment(nil, nil, nil)
    end
  end

  test "#cancel_shipment is not implemented" do
    assert_raises NotImplementedError do
      @carrier.cancel_shipment(nil)
    end
  end

  test "#find_tracking_info is not implemented" do
    assert_raises NotImplementedError do
      @carrier.find_tracking_info(nil)
    end
  end

  test "#maximum_weight returns a Measured::Weight" do
    assert_equal Measured::Weight.new(150, :pounds), @carrier.maximum_weight
  end

  test "#maximum_address_field_length default value" do
    assert_equal 255, @carrier.maximum_address_field_length
  end

  test "#requirements is an empty array" do
    assert_equal [], @carrier.send(:requirements)
  end

  test "#timestamp_from_business_day returns nil without a day" do
    assert_nil @carrier.send(:timestamp_from_business_day, nil)
  end

  test "#save_request caches the last request on the object" do
    request = Object.new
    assert_nil @carrier.last_request
    @carrier.send(:save_request, request)
    assert_equal request, @carrier.last_request
  end

  test "#timestamp_from_business_day returns two days in the future" do
    current = DateTime.parse("Tue 19 Jul 2016")
    expected = DateTime.parse("Thu 21 Jul 2016")

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 2)
    end
  end

  test "#timestamp_from_business_day returns two days in the future over a weekend" do
    current = DateTime.parse("Fri 22 Jul 2016")
    expected = DateTime.parse("Tue 26 Jul 2016")

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 2)
    end
  end

  test "#timestamp_from_business_day returns fifteen days in the future" do
    current = DateTime.parse("Wed 06 Jul 2016")
    expected = DateTime.parse("Wed 27 Jul 2016") # includes 3 weekends

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 15)
    end
  end

  test "#timestamp_from_business_day handles saturday" do
    current = DateTime.parse("Sat 09 Jul 2016")
    expected = DateTime.parse("Mon 11 Jul 2016")

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 1)
    end
  end

  test "#timestamp_from_business_day handles sunday" do
    current = DateTime.parse("Sun 10 Jul 2016")
    expected = DateTime.parse("Mon 11 Jul 2016")

    Timecop.freeze(current) do
      assert_equal expected, @carrier.send(:timestamp_from_business_day, 1)
    end
  end

  test "#timestamp_from_business_day returns a DateTime" do
    Timecop.freeze(DateTime.parse("Tue 19 Jul 2016")) do
      assert_equal DateTime, @carrier.send(:timestamp_from_business_day, 1).class
    end
  end

  test ".default_location is a valid address with defaults" do
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
