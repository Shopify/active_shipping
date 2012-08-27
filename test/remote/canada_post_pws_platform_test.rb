require 'test_helper'

# All remote tests require Canada Post development environment credentials
class CanadaPostPWSPlatformTest < Test::Unit::TestCase
  
  def setup

    @login = fixtures(:canada_post_pws_production)
    
    # 100 grams, 93 cm long, 10 cm diameter, cylinders have different volume calculations
    # @pkg1 = Package.new(1000, [93,10], :value => 10.00)
    @pkg1 = Package.new(1000, nil, :value => 10.00)

    @line_item1 = TestFixtures.line_items1

    @shipping_opts1 = {:dc => true, :cod => true, :cod_amount => 500.00, :cov => true, :cov_amount => 100.00, 
                       :so => true, :pa18 => true}

    @home_params = {
      :name        => "John Smith", 
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "123 Elm St.",
      :city        => 'Ottawa', 
      :province    => 'ON', 
      :country     => 'CA', 
      :postal_code => 'K1P 1J1'
    }
    @home = Location.new(@home_params)

    @dom_params = {
      :name        => "John Smith Sr.", 
      :company     => "",
      :phone       => '123-123-1234',
      :address1    => "5500 Oak Ave",
      :city        => 'Vancouver', 
      :province    => 'BC', 
      :country     => 'CA', 
      :postal_code => 'V5J 2T4'      
    }

    @dest_params = {
      :name     => "Frank White",
      :phone    => '123-123-1234',
      :address1 => '999 Wiltshire Blvd',
      :city     => 'Beverly Hills', 
      :state    => 'CA', 
      :country  => 'US', 
      :zip      => '90210'
    }
    @dest = Location.new(@dest_params)

    @dom_params = {
      :name        => "Mrs. Smith", 
      :company     => "",
      :phone       => "604-555-1212",
      :address1    => "5000 Oak St.",
      :address2    => "",
      :city        => 'Vancouver', 
      :province    => 'BC', 
      :country     => 'CA', 
      :postal_code => 'V5J 2N2'
    }

    @intl_params = {
      :name        => "Mrs. Yamamoto", 
      :company     => "",
      :phone       => "011-123-123-1234",
      :address1    => "123 Yokohama Road",
      :address2    => "",
      :city        => 'Tokyo', 
      :province    => '', 
      :country     => 'JP'      
    }

    @cp = CanadaPostPWS.new(@login)
    @cp.logger = Logger.new(STDOUT)

    @customer_number = @login[:customer_number]
    @customer_api_key = @login[:customer_api_key]
    @customer_secret = @login[:customer_secret]

  end

  def build_options
    {
      :customer_number => @customer_number,
      :customer_api_key => @customer_api_key,
      :customer_secret => @customer_secret
    }
  end

  def test_rates
    rates = @cp.find_rates(@home_params, @dom_params, [@pkg1], build_options)
    assert_equal RateResponse, rates.class
    assert_equal RateEstimate, rates.rates.first.class
  end

  def test_rates_with_insurance_changes_price
    rates = @cp.find_rates(@home_params, @dom_params, [@pkg1], build_options)
    insured_rates = @cp.find_rates(@home_params, @dom_params, [@pkg1], build_options.merge(@shipping_opts1))
    assert_not_equal rates.rates.first.price, insured_rates.rates.first.price
  end

  def test_rates_with_invalid_customer_raises_exception
    opts = {:customer_number => "0000000000", :service => "DOM.XP"}
    assert_raise ResponseError do
      @cp.find_rates(@home_params, @dom_params, [@pkg1], opts)
    end
  end

  def test_tracking
    pin = "1371134583769923" # valid pin
    response = @cp.find_tracking_info(pin, build_options)
    assert_equal 'Xpresspost', response.service_name
    assert response.expected_date.is_a?(Date)
    assert response.customer_number
    assert_equal 10, response.shipment_events.count
  end

  def test_tracking_invalid_pin_raises_exception
    pin = "000000000000000"
    exception = assert_raise ResponseError do
      response = @cp.find_tracking_info(pin, build_options)
    end
    assert_equal "No Pin History", exception.message
  end

  def test_create_shipment_with_invalid_customer_raises_exception
    opts = {:customer_number => "0000000000", :service => "DOM.XP"}
    assert_raise ResponseError do
      @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)
    end
  end

  def test_register_merchant
    response = @cp.register_merchant
    assert response.is_a?(CPPWSRegisterResponse)
    assert_match /^(\d|[a-f]){22}$/, response.token_id
  end

  def test_merchant_details_empty_details
    response = @cp.register_merchant
    exception = assert_raise ResponseError do
      response = @cp.retrieve_merchant_details({:token_id => response.token_id})
    end
    assert_equal "No Merchant Info", exception.message
  end

  def test_find_services_no_country
    response = @cp.find_services(nil, build_options)
    assert response
  end

  def test_find_services_country_JP
    response = @cp.find_services('JP', build_options)
    assert response
  end

  def test_find_services_invalid_country
    exception = assert_raise ResponseError do
      response = @cp.find_services('XX', build_options)
    end
    assert_equal "A valid destination country must be supplied.", exception.message
  end

  def test_find_service_options_no_country
    assert response = @cp.find_service_options("INT.XP", nil, build_options)
    assert_equal "INT.XP", response[:service_code]
    assert_equal "Xpresspost International", response[:service_name]
    assert_equal 4, response[:options].size
    assert_equal "COV", response[:options][0][:code]
    assert_equal false, response[:options][0][:required]
    assert_equal true, response[:options][0][:qualifier_required]
    assert_equal 5000, response[:options][0][:qualifier_max]
    assert_equal 0, response[:restrictions][:min_weight]
    assert_equal 30000, response[:restrictions][:max_weight]
    assert_equal 0.1, response[:restrictions][:min_length]
    assert_equal 150, response[:restrictions][:max_length]
    assert_equal 0.1, response[:restrictions][:min_height]
    assert_equal 150, response[:restrictions][:max_height]
    assert_equal 0.1, response[:restrictions][:min_width]
    assert_equal 150, response[:restrictions][:max_width]
  end

  def test_find_service_options
    assert response = @cp.find_service_options("INT.XP", "JP", build_options)
    assert_equal "INT.XP", response[:service_code]
    assert_equal "Xpresspost International", response[:service_name]
    assert_equal 3, response[:options].size
    assert_equal "COV", response[:options][0][:code]
    assert_equal false, response[:options][0][:required]
    assert_equal true, response[:options][0][:qualifier_required]
    assert_equal 1000, response[:options][0][:qualifier_max]
    assert_equal 0, response[:restrictions][:min_weight]
    assert_equal 30000, response[:restrictions][:max_weight]
    assert_equal 0.1, response[:restrictions][:min_length]
    assert_equal 150, response[:restrictions][:max_length]
    assert_equal 0.1, response[:restrictions][:min_height]
    assert_equal 150, response[:restrictions][:max_height]
    assert_equal 0.1, response[:restrictions][:min_width]
    assert_equal 150, response[:restrictions][:max_width]
  end

  def test_find_option_details
    assert response = @cp.find_option_details("SO", build_options)
    assert_equal "SO", response[:code]
    assert_equal "Signature option", response[:name]
    assert_equal "FEAT", response[:class]
    assert_equal true, response[:prints_on_label]
    assert_equal false, response[:qualifier_required]
    assert_equal 1, response[:conflicting_options].size
    assert_equal "LAD", response[:conflicting_options][0]
    assert_equal 1, response[:prerequisite_options].size
    assert_equal "DC", response[:prerequisite_options][0]
  end

  def test_find_option_details_french
    cp = CanadaPostPWS.new(@login.merge({:language => 'fr'}))
    assert response = cp.find_option_details("LAD", build_options)
    assert_equal "LAD", response[:code]
    assert_equal "Laisser à la porte (pas d'avis)", response[:name]
  end

end