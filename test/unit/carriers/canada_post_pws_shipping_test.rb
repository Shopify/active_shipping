require 'test_helper'
require 'pp'
class CanadaPostPwsShippingTest < Test::Unit::TestCase

  def setup
    login = fixtures(:canada_post_pws)
    
    # 100 grams, 93 cm long, 10 cm diameter, cylinders have different volume calculations
    @pkg1 = Package.new(25, [93,10], :cylinder => true)

    # 7.5 lbs, times 16 oz/lb., 15x10x4.5 inches, not grams, not centimetres
    @pkg2 = Package.new(  (7.5 * 16), [15, 10, 4.5], :units => :imperial)

    @line_item1 = TestFixtures.line_items1
    
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

    @us_params = {
      :name        => "John Smith", 
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "123 Elm St.",
      :address2    => "",
      :city        => 'Beverly Hills', 
      :province    => 'CA', 
      :country     => 'US', 
      :postal_code => '90210'
    }

    @paris_params = {
      :name        => "John Smith", 
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "5 avenue Anatole France - Champ de Mars",
      :address2    => "",
      :city        => 'Paris', 
      :province    => '', 
      :country     => 'FR', 
      :postal_code => '75007'
    }

    @shipping_opts1 = {:dc => true, :cod => :true, :cod_amount => 50.00, :cod_includes_shipping => true, 
                       :cod_method_of_payment => 'CSH', :cov => true, :cov_amount => 100.00, 
                       :so => true, :pa18 => true}

    @default_options = {:customer_number => '123456'}

    @DEFAULT_RESPONSE = {
      :shipping_id => "406951321983787352",
      :tracking_number => "11111118901234",
      :label_url => "https://ct.soa-gw.canadapost.ca/ers/artifact/c70da5ed5a0d2c32/20238/0"
    }

    @cp = CanadaPostPWS.new(login)
  end

  def test_build_shipment_customs_node
    options = @default_options.dup
    destination = Location.new(@us_params)
    assert_not_nil response = @cp.shipment_customs_node(destination, @line_item1, options)
    doc = REXML::Document.new(response.to_s)
    assert root_node = doc.elements['customs']
    assert_equal "CAD", root_node.get_text('currency').to_s
    assert items_node = root_node.elements['sku-list']
    assert_equal 2, items_node.size
  end

  def test_build_shipment_request_for_domestic
    options = @default_options.dup
    request = @cp.build_shipment_request(@home_params, @dom_params, @pkg1, @line_item1, options)
    assert_not_nil request
  end

  def test_build_shipment_request_for_US
    options = @default_options.dup
    request = @cp.build_shipment_request(@home_params, @us_params, @pkg1, @line_item1, options)
    assert_not_nil request
    doc = REXML::Document.new(request)
    assert root_node = doc.elements['non-contract-shipment']
    assert delivery_spec = root_node.elements['delivery-spec']
    assert destination = delivery_spec.elements['destination']
    assert address_details = destination.elements['address-details']
    assert_equal 'US', address_details.get_text('country-code').to_s
  end

  def test_build_shipment_request_for_international
    options = @default_options.dup
    request = @cp.build_shipment_request(@home_params, @paris_params, @pkg1, @line_item1, options)
    assert_not_nil request
  end

  def test_create_shipment_request_with_options
    options = @default_options.merge(@shipping_opts1)
    request = @cp.build_shipment_request(@home_params, @paris_params, @pkg1, @line_item1, options)
    assert_not_nil request
    doc = REXML::Document.new(request)
    assert root_node = doc.elements['non-contract-shipment']
    assert delivery_spec = root_node.elements['delivery-spec']
    assert options = delivery_spec.elements['options']
    assert_equal 5, options.elements.size
  end

  def test_build_shipping_request_with_zero_weight
    options = @default_options.merge(@shipping_opts1)
    package = Package.new(0, [93,10])
    request = @cp.build_shipment_request(@home_params, @dom_params, package, @line_item1, options)
    assert_not_nil request
    doc = REXML::Document.new(request)
    assert root_node = doc.elements['non-contract-shipment']
    assert delivery_spec = root_node.elements['delivery-spec']
    assert parcel_node = delivery_spec.elements['parcel-characteristics']
    assert_equal '0.001', parcel_node.get_text('weight').to_s
  end

  def test_create_shipment_domestic
    options = @default_options.dup
    response = xml_fixture('canadapost_pws/shipment_response')
    @cp.expects(:ssl_post).once.returns(response)
    response = @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, options)
    assert response.is_a?(CPPWSShippingResponse)
    assert_equal @DEFAULT_RESPONSE[:shipping_id], response.shipping_id
    assert_equal @DEFAULT_RESPONSE[:tracking_number], response.tracking_number
    assert_equal @DEFAULT_RESPONSE[:label_url], response.label_url
  end

  def test_create_shipment_us
    options = @default_options.dup
    response = xml_fixture('canadapost_pws/shipment_response')
    @cp.expects(:ssl_post).once.returns(response)
    response = @cp.create_shipment(@home_params, @us_params, @pkg1, @line_item1, options)
    assert response.is_a?(CPPWSShippingResponse)
    assert_equal @DEFAULT_RESPONSE[:shipping_id], response.shipping_id
    assert_equal @DEFAULT_RESPONSE[:tracking_number], response.tracking_number
    assert_equal @DEFAULT_RESPONSE[:label_url], response.label_url
  end

  def test_create_shipment_international
    options = @default_options.dup
    response = xml_fixture('canadapost_pws/shipment_response')
    @cp.expects(:ssl_post).once.returns(response)
    response = @cp.create_shipment(@home_params, @us_params, @pkg1, @line_item1, options)
    assert response.is_a?(CPPWSShippingResponse)
    assert_equal @DEFAULT_RESPONSE[:shipping_id], response.shipping_id
    assert_equal @DEFAULT_RESPONSE[:tracking_number], response.tracking_number
    assert_equal @DEFAULT_RESPONSE[:label_url], response.label_url
  end

  def test_retrieve_shipping_label
    shipping_response = CPPWSShippingResponse.new(true, '', {}, @DEFAULT_RESPONSE)
    @cp.expects(:ssl_get).once.returns(file_fixture('label1.pdf'))
    response = @cp.retrieve_shipping_label(shipping_response)
    assert_not_nil response
    assert_equal "%PDF", response[0...4]
  end

  def test_retrieve_shipment
    options = @default_options.dup
    shipping_response = CPPWSShippingResponse.new(true, '', {}, @DEFAULT_RESPONSE)
    response = xml_fixture('canadapost_pws/shipment_response')
    @cp.expects(:ssl_post).once.returns(response)
    response = @cp.retrieve_shipment(shipping_response.shipping_id, options)
    assert response.is_a?(CPPWSShippingResponse)
    assert_equal @DEFAULT_RESPONSE[:shipping_id], response.shipping_id
    assert_equal @DEFAULT_RESPONSE[:tracking_number], response.tracking_number
    assert_equal @DEFAULT_RESPONSE[:label_url], response.label_url
  end

  def test_parse_find_shipment_receipt_response
    body = xml_fixture('canadapost_pws/receipt_response')
    response = @cp.parse_shipment_receipt_response(body)
    assert_equal "J4W4T0", response[:final_shipping_point]
    assert_equal "BP BROSSARD", response[:shipping_point_name]
    assert_equal "DOM.EP", response[:service_code]
    assert_equal 15.000, response[:rated_weight]
    assert_equal 18.10, response[:base_amount]
    assert_equal 19.46, response[:pre_tax_amount]
    assert_equal 0.00, response[:gst_amount]
    assert_equal 0.00, response[:pst_amount]
    assert_equal 2.53, response[:hst_amount]
    assert_equal 1, response[:priced_options].size
    assert_equal 0.0, response[:priced_options]['DC']
    assert_equal 21.99, response[:charge_amount]
    assert_equal 'CAD', response[:currency]
    assert_equal 1, response[:expected_transit_days]
    assert_equal '2012-03-14', response[:expected_delivery_date]
  end

  def test_find_shipment_receipt
    options = @default_options.dup
    xml_response = xml_fixture('canadapost_pws/receipt_response')
    @cp.expects(:ssl_get).once.returns(xml_response)
    response = @cp.find_shipment_receipt('1234567', options)
    assert_equal @cp.parse_shipment_receipt_response(xml_response), response
  end

end
