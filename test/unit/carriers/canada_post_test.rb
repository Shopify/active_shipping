require 'test_helper'

class CanadaPostTest < Test::Unit::TestCase
  def setup
    login = fixtures(:canada_post)

    @carrier  = CanadaPost.new(login)
    @french_carrier  = CanadaPost.new(login.merge(:french => true))

    @request  = xml_fixture('canadapost/example_request')
    @response = xml_fixture('canadapost/example_response')
    @response_french = xml_fixture('canadapost/example_response_french')
    @bad_response = xml_fixture('canadapost/example_response_error')

    @origin      = {:address1 => "61A York St", :city => "Ottawa", :province => "ON", :country => "Canada", :postal_code => "K1N 5T2"}
    @destination = {:city => "Beverly Hills", :state => "CA", :country => "United States", :postal_code => "90210"}
    @line_items  = [Package.new(500, [2, 3, 4], :description => "a box full of stuff", :value => 2500)]
  end

  def test_parse_rate_response_french
    assert_equal @request, @french_carrier.build_rate_request(@origin, @destination, 24, @line_items)
  end

  def test_parse_rate_response_french
    @french_carrier.expects(:ssl_post).returns(@response_french)
    rate_estimates = @french_carrier.find_rates(@origin, @destination, @line_items)
    # rate_response = @french_carrier.send :parse_rate_response, @response_french, @origin, @desination

    rate_estimates.rates.each do |rate|
      assert_instance_of RateEstimate, rate
      assert_instance_of DateTime, rate.delivery_date
      assert_instance_of DateTime, rate.shipping_date
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.total_price
    end

    rate_estimates.boxes.each do |box|
      assert_instance_of CanadaPost::Box, box
      assert_instance_of String, box.name
      assert_instance_of Float, box.weight
      assert_instance_of Float, box.expediter_weight
      assert_instance_of Float, box.length
      assert_instance_of Float, box.height
      assert_instance_of Float, box.width

      box.packedItems.each do |p|
        assert_instance_of Fixnum, p.quantity
        assert_instance_of String, p.description
      end
    end
  end

  def test_build_rate_request
    @carrier.expects(:commit).with(@request, @origin, @destination, {})
    @carrier.find_rates(@origin, @destination, @line_items)
  end

  def test_parse_rate_response
    @carrier.expects(:ssl_post).returns(@response)
    rate_estimates = @carrier.find_rates(@origin, @destination, @line_items)

    rate_estimates.rates.each do |rate|
      assert_instance_of RateEstimate, rate
      assert_instance_of DateTime, rate.delivery_date
      assert_instance_of DateTime, rate.shipping_date
      assert_instance_of String, rate.service_name
      assert_instance_of Fixnum, rate.total_price
    end

    rate_estimates.boxes.each do |box|
      assert_instance_of CanadaPost::Box, box
      assert_instance_of String, box.name
      assert_instance_of Float, box.weight
      assert_instance_of Float, box.expediter_weight
      assert_instance_of Float, box.length
      assert_instance_of Float, box.height
      assert_instance_of Float, box.width

      box.packedItems.each do |p|
        assert_instance_of Fixnum, p.quantity
        assert_instance_of String, p.description
      end
    end
  end

  def test_non_success_parse_rate_response
    @carrier.expects(:ssl_post).returns(@bad_response)

    error = assert_raise ActiveMerchant::Shipping::ResponseError do
      rate_estimates = @carrier.find_rates(@origin, @destination, @line_items)
    end

    assert_equal 'Parcel too heavy to be shipped with CPC.', error.message
  end

  def test_turn_around_time
    @carrier.expects(:commit).with do |request, _options|
      parsed_request = Hash.from_xml(request)
      parsed_request['eparcel']['ratesAndServicesRequest']['turnAroundTime'] == "0"
    end
    @carrier.find_rates(@origin, @destination, @line_items, :turn_around_time => 0)
  end

  def test_build_line_items
    xml_line_items = @carrier.send(:build_line_items, @line_items)
    assert_instance_of XmlNode, xml_line_items

    xml_string = xml_line_items.to_s
    assert_match /a box full of stuff/, xml_string
  end

  def test_non_iso_country_names
    @destination[:country] = 'RU'

    @carrier.expects(:ssl_post).with(anything, regexp_matches(%r{<country>Russia</country>})).returns(@response)
    rate_estimates = @carrier.find_rates(@origin, @destination, @line_items)
  end

  def test_delivery_range_based_on_delivery_date
    @carrier.expects(:ssl_post).returns(@response)
    rate_estimates = @carrier.find_rates(@origin, @destination, @line_items)

    delivery_date = Date.new(2010, 8, 4)
    assert_equal [delivery_date] * 2, rate_estimates.rates[0].delivery_range
    assert_equal [delivery_date] * 2, rate_estimates.rates[1].delivery_range
    assert_equal [delivery_date + 2.days] * 2, rate_estimates.rates[2].delivery_range
  end

  def test_delivery_range_with_invalid_date
    @response = xml_fixture('canadapost/example_response_with_strange_delivery_date')
    @carrier.expects(:ssl_post).returns(@response)
    rate_estimates = @carrier.find_rates(@origin, @destination, @line_items)

    assert_equal [], rate_estimates.rates[0].delivery_range
  end

  def test_line_items_with_nil_values
    @line_items << Package.new(500, [2, 3, 4], :description => "another box full of stuff", :value => nil)
    @carrier.find_rates(@origin, @destination, @line_items)
  end
end
