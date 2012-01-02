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

    @shipping_opts1 = {:delivery_confirm => true, :cod => :true, :cod_amount => 50.00, :cod_includes_shipping => true, 
                       :cod_method_of_payment => 'CSH', :insurance => true, :insurance_amount => 100.00, 
                       :signature_required => true, :pa18 => true}

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
    assert_equal "USD", root_node.get_text('currency').to_s
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

  # build_location_node

  # def test_location_node_for_sender
  #   response = @cp.send(:build_location_node, 'sender', Location.new(@address_params))
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_equal @address_params[:name], doc.xpath('//sender/name').first.content
  #   assert_equal @address_params[:company], doc.xpath('//sender/company').first.content
  #   assert_equal @address_params[:phone], doc.xpath('//sender/contact-phone').first.content
  #   assert doc.xpath('//sender/address-details')
  # end

  # def test_location_node_for_sender_with_no_company
  #   response = @cp.send(:build_location_node, 'sender', Location.new(@address_params.merge(:company => nil)))
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_equal @address_params[:name], doc.xpath('//sender/company').first.content
  # end

  # def test_location_node_for_sender_with_no_address2_or_address3
  #   response = @cp.send(:build_location_node, 'sender', Location.new(@address_params.merge(:address2 => nil)))
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_nil doc.xpath('//sender/address2').first
  # end

  # def test_location_node_for_dest
  #   response = @cp.send(:build_location_node, 'destination', Location.new(@address_params))
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_equal @address_params[:name], doc.xpath('//destination/name').first.content
  # end

  # # build_shipping_preference_options

  # def test_build_shipping_preference_options
  #   response = @cp.send(:build_shipping_preference_options, {})
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_equal 'true', doc.xpath('//preferences/show-packing-instructions').first.content
  #   assert_equal 'true', doc.xpath('//preferences/show-postage-rate').first.content
  #   assert_equal 'true', doc.xpath('//preferences/show-insured-value').first.content
  # end

  # build_print_preference_options

  # def test_build_print_preference_options
  #   response = @cp.send(:build_print_preference_options, {})
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_equal "paper", doc.xpath('//print-preferences/output-format').first.content
  #   assert_equal "PDF", doc.xpath('//print-preferences/encoding').first.content
  # end

  # # build_build_settlement_info

  # def test_build_settlement_info
  #   response = @cp.send(:build_settlement_info, {:customer_number => '123456'})
  #   doc = Nokogiri::XML(response.to_s)
  #   assert_equal "123456", doc.xpath('//settlement-info/contract-id').first.content
  #   assert_equal "Account", doc.xpath('//settlement-info/intended-method-of-payment').first.content
  # end

end



# <?xml version="1.0"?>
# <shipment xmlns="http://www.canadapost.ca/ws/shipment">
#   <group-id>test</group-id>
#   <requested-shipping-point>K1P1J1</requested-shipping-point>
#   <delivery-spec>
#     <service-code>DOM.EP</service-code>
#     <sender>
#       <name>John Smith</name>
#       <company>test</company>
#       <contact-phone>613-555-1212</contact-phone>
#       <address-details>
#         <address-line-1>123 Elm St.</address-line-1>
#         <city>Ottawa</city>
#         <prov-state>ON</prov-state>
#         <country-code>CA</country-code>
#         <postal-zip-code>K1P1J1</postal-zip-code>
#       </address-details>
#     </sender>
#     <destination>
#       <name>Jane White</name>
#       <address-details>
#         <address-line-1>5555 Trafalgar St.</address-line-1>
#         <city>Vancouver</city>
#         <prov-state>BC</prov-state>
#         <country-code>CA</country-code>
#         <postal-zip-code>V5J2T2</postal-zip-code>
#       </address-details>
#     </destination>
#     <parcel-characteristics>
#       <weight>0.025</weight>
#       <mailing-tube>true</mailing-tube>
#     </parcel-characteristics>
#     <print-preferences>
#       <output-format>paper</output-format>
#       <encoding>PDF</encoding>
#     </print-preferences>
#     <preferences>
#       <show-packing-instructions>true</show-packing-instructions>
#       <show-postage-rate>true</show-postage-rate>
#       <show-insured-value>true</show-insured-value>
#     </preferences>
#     <settlement-info>
#       <contract-id>0008035576</contract-id>
#       <intended-method-of-payment>Account</intended-method-of-payment>
#     </settlement-info>
#   </delivery-spec>
# </shipment>

# <?xml version="1.0" encoding="UTF-8"?>
# <shipment-info xmlns="http://www.canadapost.ca/ws/shipment">
#   <shipment-id>340531309186521749</shipment-id>
#   <shipment-status>created</shipment-status>
#   <tracking-pin>7023210883561103</tracking-pin>
#   <links>
#     <link rel="self" href="https://ct.soa-gw.canadapost.ca/rs/0008035576/0008035576/shipment/340531309186521749" media-type="application/vnd.cpc.shipment+xml"/>
#     <link rel="details" href="https://ct.soa-gw.canadapost.ca/rs/0008035576/0008035576/shipment/340531309186521749/details" media-type="application/vnd.cpc.shipment+xml"/>
#     <link rel="group" href="https://ct.soa-gw.canadapost.ca/rs/0008035576/0008035576/shipment?groupId=123456" media-type="application/vnd.cpc.shipment+xml"/>
#     <link rel="price" href="https://ct.soa-gw.canadapost.ca/rs/0008035576/0008035576/shipment/340531309186521749/price" media-type="application/vnd.cpc.shipment+xml"/>
#     <link rel="label" href="https://ct.soa-gw.canadapost.ca/ers/artifact/c70da5ed5a0d2c32/10238/0" media-type="application/pdf" index="0"/>
#   </links>
# </shipment-info>
