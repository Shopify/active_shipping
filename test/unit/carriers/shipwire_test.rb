require 'test_helper'

class ShipwireTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def setup
    @carrier = Shipwire.new(:login => 'l', :password => 'p')
    @items   = [{ :sku => 'AF0001', :quantity => 1 }, { :sku => 'AF0002', :quantity => 2 }]
  end

  def test_response_with_no_rates_is_unsuccessful
    @carrier.expects(:ssl_post).returns(xml_fixture('shipwire/no_rates_response'))

    assert_raises(ResponseError) do
      @carrier.find_rates(
        location_fixtures[:ottawa],
        location_fixtures[:beverly_hills],
        package_fixtures.values_at(:book, :wii),
        :order_id => '#1000',
        :items => @items
      )
    end
  end

  def test_successfully_get_international_rates
    date = DateTime.parse("Mon 01 Aug 2011")
    @carrier.expects(:ssl_post).returns(xml_fixture('shipwire/international_rates_response'))

    Timecop.freeze(date) do
      response = @carrier.find_rates(
                   location_fixtures[:ottawa],
                   location_fixtures[:london],
                   package_fixtures.values_at(:book, :wii),
                   :order_id => '#1000',
                   :items => @items
                 )

      assert response.success?

      assert_equal 1, response.rates.size

      assert international = response.rates.first
      assert_equal "INTL", international.service_code
      assert_equal "UPS", international.carrier
      assert_equal "UPS Standard", international.service_name
      assert_equal 2806, international.total_price
      assert_equal [date + 1.day, date + 7.days], international.delivery_range
    end
  end

  def test_successfully_get_domestic_rates
    date = DateTime.parse("Mon 01 Aug 2011")
    @carrier.expects(:ssl_post).returns(xml_fixture('shipwire/rates_response'))

    Timecop.freeze(date) do
      response = @carrier.find_rates(
                   location_fixtures[:ottawa],
                   location_fixtures[:beverly_hills],
                   package_fixtures.values_at(:book, :wii),
                   :order_id => '#1000',
                   :items => @items
                 )

      assert response.success?

      assert_equal 3, response.rates.size

      assert ground  = response.rates.find { |r| r.service_code == "GD" }
      assert_equal "UPS", ground.carrier
      assert_equal "UPS Ground", ground.service_name
      assert_equal 773, ground.total_price
      assert_equal [date + 1.day, date + 7.days], ground.delivery_range

      assert two_day = response.rates.find { |r| r.service_code == "2D" }
      assert_equal "UPS", two_day.carrier
      assert_equal "UPS Second Day Air", two_day.service_name
      assert_equal 1364, two_day.total_price
      assert_equal [date + 2.days, date + 2.days], two_day.delivery_range

      assert one_day = response.rates.find { |r| r.service_code == "1D" }
      assert_equal "USPS", one_day.carrier
      assert_equal "USPS Express Mail", one_day.service_name
      assert_equal 2525, one_day.total_price
      assert_equal [date + 1.day, date + 1.day], one_day.delivery_range
    end
  end

  def test_gracefully_handle_new_carrier
    @carrier.expects(:ssl_post).returns(xml_fixture('shipwire/new_carrier_rate_response'))

    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:beverly_hills],
                 package_fixtures.values_at(:book, :wii),
                 :order_id => '#1000',
                 :items => @items
               )
    assert response.success?
    assert_equal 1, response.rates.size
    assert ground = response.rates.first
    assert_equal "FESCO", ground.carrier
  end

  def test_find_rates_requires_items_option
    assert_raises(ArgumentError) do
      @carrier.find_rates(
        location_fixtures[:ottawa],
        location_fixtures[:beverly_hills],
        package_fixtures.values_at(:book, :wii)
      )
    end
  end

  def test_validate_credentials_with_valid_credentials
    @carrier.expects(:ssl_post).returns(xml_fixture('shipwire/no_rates_response'))
    assert @carrier.valid_credentials?
  end

  def test_validate_credentials_with_invalid_credentials
    response = stub(:code => '401', :body => 'Could not verify Username/EmailAddress and Password combination')

    @carrier.expects(:ssl_post).raises(ActiveUtils::ResponseError.new(response))
    assert !@carrier.valid_credentials?
  end

  def test_rate_request_includes_address_name_if_provided
    name = CGI.escape("<Full>Bob Bobsen</Full>")
    @carrier.expects(:ssl_post).with(anything, includes(name)).returns(xml_fixture('shipwire/rates_response'))

    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:new_york_with_name],
                 package_fixtures.values_at(:book, :wii),
                 :order_id => '#1000',
                 :items => @items
               )

    assert response.success?
  end

  def test_rate_request_does_not_include_address_name_element_if_not_provided
    name = CGI.escape("<Name>")
    @carrier.expects(:ssl_post).with(anything, Not(regexp_matches(Regexp.new(name)))).returns(xml_fixture('shipwire/rates_response'))

    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:new_york],
                 package_fixtures.values_at(:book, :wii),
                 :order_id => '#1000',
                 :items => @items
               )

    assert response.success?
  end

  def test_rate_request_without_delivery_estimate
    @carrier.expects(:ssl_post).returns(xml_fixture('shipwire/rates_response_no_estimate'))
    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:new_york],
                 package_fixtures.values_at(:book, :wii),
                 :order_id => '#1000',
                 :items => @items
               )

    assert response.success?
    assert_equal [], response.rates[0].delivery_range
  end

  def test_rate_request_includes_company_if_provided
    company = CGI.escape("<Company>Tampa Company</Company>")
    @carrier.expects(:ssl_post).with(anything, includes(company)).returns(xml_fixture('shipwire/rates_response'))

    response = @carrier.find_rates(
                 location_fixtures[:ottawa],
                 location_fixtures[:real_home_as_commercial],
                 package_fixtures.values_at(:book, :wii),
                 :order_id => '#1000',
                 :items => @items
               )

    assert response.success?
  end

  def test_maximum_address_field_length
    assert_equal 255, @carrier.maximum_address_field_length
  end
end
