require 'test_helper'

class CanadaPostPWSTest < Test::Unit::TestCase
  
  def setup

    @login = fixtures(:canada_post_pws)
    
    # 100 grams, 93 cm long, 10 cm diameter, cylinders have different volume calculations
    # @pkg1 = Package.new(1000, [93,10], :value => 10.00)
    @pkg1 = Package.new(1000, nil, :value => 10.00)

    @line_item1 = TestFixtures.line_items1

    @shipping_opts1 = {:delivery_confirm => true, :cod => true, :cod_amount => 500.00, :insurance => true, :insurance_amount => 100.00, 
                       :signature_required => true, :pa18 => true}

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

    @cp = CanadaPostPWS.new(@login.merge(:endpoint => "https://ct.soa-gw.canadapost.ca/"))
    @cp.logger = Logger.new(STDOUT)

    @DEFAULT_RESPONSE = {
      :shipping_id => "406951321983787352",
      :tracking_number => "11111118901234",
      :label_url => "https://ct.soa-gw.canadapost.ca/ers/artifact/c70da5ed5a0d2c32/20238/0"
    }

  end

  def test_rates
    opts = {:customer_number => @login[:customer_number]}
    rates = @cp.find_rates(@home_params, @dom_params, [@pkg1], opts)
    assert_equal RateResponse, rates.class
    assert_equal RateEstimate, rates.rates.first.class
  end

  def test_rates_with_insurance_changes_price
    opts = {:customer_number => @login[:customer_number]}
    rates = @cp.find_rates(@home_params, @dom_params, [@pkg1], opts)
    insured_rates = @cp.find_rates(@home_params, @dom_params, [@pkg1], opts.merge(@shipping_opts1))
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
    response = @cp.find_tracking_info(pin, {})
    assert_equal 'Xpresspost', response.service_name
    assert response.expected_date.is_a?(Date)
    assert response.customer_number
    assert_equal 10, response.shipment_events.count
  end

  def test_create_shipment
    opts = {:customer_number => @login[:customer_number], :service => "DOM.XP"}
    response = @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)
    assert response.is_a?(CPPWSShippingResponse)
    assert_equal @DEFAULT_RESPONSE[:shipping_id], response.shipping_id
    assert_equal @DEFAULT_RESPONSE[:tracking_number], response.tracking_number
    assert_equal @DEFAULT_RESPONSE[:label_url], response.label_url
  end

  def test_create_shipment_with_options
    opts = {:customer_number => @login[:customer_number], :service => "USA.EP"}
    opts.merge! @shipping_opts1
    response = @cp.create_shipment(@home_params, @dest_params, @pkg1, @line_item1, opts)
    assert response.is_a?(CPPWSShippingResponse)
    assert_equal @DEFAULT_RESPONSE[:shipping_id], response.shipping_id
    assert_equal @DEFAULT_RESPONSE[:tracking_number], response.tracking_number
    assert_equal @DEFAULT_RESPONSE[:label_url], response.label_url
  end

  def test_retrieve_shipping_label
    shipping_response = CPPWSShippingResponse.new(true, '', {}, @DEFAULT_RESPONSE)
    response = @cp.retrieve_shipping_label(shipping_response)
    assert_not_nil response
    assert_equal "%PDF", response[0...4]
  end

  def test_create_shipment_with_invalid_customer_raises_exception
    opts = {:customer_number => "0000000000", :service => "DOM.XP"}
    assert_raise ResponseError do
      @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)
    end
  end

end