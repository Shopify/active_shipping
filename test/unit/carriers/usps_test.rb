require 'test_helper'

class USPSTest < Test::Unit::TestCase

  def setup
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = USPS.new(:login => 'login')
    @tracking_response = xml_fixture('usps/tracking_response')
    @tracking_response_failure = xml_fixture('usps/tracking_response_failure')
  end

  def test_tracking_failure_should_raise_exception
    @carrier.expects(:commit).returns(@tracking_response_failure)
    assert_raises ResponseError do
      @carrier.find_tracking_info('abc123xyz', :test => true)
    end
  end

  def test_find_tracking_info_should_handle_not_found_error
    @carrier.expects(:commit).returns(xml_fixture('usps/tracking_response_test_error'))
    assert_raises ResponseError do
      @carrier.find_tracking_info('9102901000462189604217', :test => true)
    end
  end

  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(@tracking_response)
    assert_instance_of ActiveMerchant::Shipping::TrackingResponse, @carrier.find_tracking_info('9102901000462189604217', :test => true)
    @carrier.expects(:commit).returns(@tracking_response)
    assert_equal 'ActiveMerchant::Shipping::TrackingResponse', @carrier.find_tracking_info('EJ958083578US').class.name
  end

  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217', :test => true)
    assert_equal 7, response.shipment_events.size
  end
  
  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217', :test => true)
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end
  
  def test_find_tracking_info_should_have_correct_timestamps_for_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217', :test => true)
    assert_equal ['2012-01-22 16:30:00 UTC',
                 '2012-01-22 17:00:00 UTC',
                 '2012-01-23 02:49:00 UTC',
                 '2012-01-24 07:45:00 UTC',
                 '2012-01-26 11:21:00 UTC',
                 '2012-01-27 08:03:00 UTC',
                 '2012-01-27 08:13:00 UTC'], response.shipment_events.map{ |e| e.time.strftime('%Y-%m-%d %H:%M:00 %Z') }
  end

  def test_find_tracking_info_should_have_correct_names_for_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217')
    assert_equal ["PICKED UP BY SHIPPING PARTNER",
                 "ARRIVED SHIPPING PARTNER FACILITY",
                 "DEPARTED SHIPPING PARTNER FACILITY",
                 "DEPARTED SHIPPING PARTNER FACILITY",
                 "ARRIVAL AT POST OFFICE",
                 "SORTING COMPLETE",
                 "OUT FOR DELIVERY"], response.shipment_events.map(&:name)
  end

  def test_find_tracking_info_should_have_correct_locations_for_shipment_events
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217', :test => true)
    assert_equal ["PHOENIX, AZ, 85043",
                 "PHOENIX, AZ, 85043",
                 "PHOENIX, AZ, 85043",
                 "GRAND PRAIRIE, TX, 75050",
                 "DES MOINES, IA, 50311",
                 "DES MOINES, IA, 50311",
                 "DES MOINES, IA, 50311"], response.shipment_events.map{|e| e.location}.map{|l| "#{l.city}, #{l.state}, #{l.postal_code}"}
  end

  def test_find_tracking_info_destination
    # USPS API doesn't tell where it's going
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217', :test => true)
    assert_equal response.destination, nil
  end

  def test_find_tracking_info_tracking_number
    @carrier.expects(:commit).returns(@tracking_response)
    response = @carrier.find_tracking_info('9102901000462189604217', :test => true)
    assert_equal response.tracking_number, '9102901000462189604217'
  end

  def test_size_codes
    assert_equal 'REGULAR', USPS.size_code_for(Package.new(2, [1,12,1], :units => :imperial))
    assert_equal 'LARGE', USPS.size_code_for(Package.new(2, [12.1,1,1], :units => :imperial))
    assert_equal 'LARGE', USPS.size_code_for(Package.new(2, [1000,1000,1000], :units => :imperial))
  end
  
  # TODO: test_parse_domestic_rate_response
  # TODO: test_build_us_rate_request
  
  def test_build_world_rate_request
    expected_request = "<IntlRateV2Request USERID='login'><Package ID='0'><Pounds>0</Pounds><Ounces>9</Ounces><MailType>Package</MailType><GXG><POBoxFlag>N</POBoxFlag><GiftFlag>N</GiftFlag></GXG><ValueOfContents>0.0</ValueOfContents><Country><![CDATA[Canada]]></Country><Container>RECTANGULAR</Container><Size>REGULAR</Size><Width>5.51</Width><Length>7.48</Length><Height>0.79</Height><Girth>12.60</Girth></Package></IntlRateV2Request>"
    @carrier.expects(:commit).with(:world_rates, URI.encode(expected_request), false).returns(expected_request)
    @carrier.expects(:parse_rate_response)
    @carrier.find_rates(@locations[:beverly_hills], @locations[:ottawa], @packages[:book], :test => true)
  end
  
  def test_build_world_rate_request_with_package_value
    expected_request = "<IntlRateV2Request USERID='login'><Package ID='0'><Pounds>0</Pounds><Ounces>120</Ounces><MailType>Package</MailType><GXG><POBoxFlag>N</POBoxFlag><GiftFlag>N</GiftFlag></GXG><ValueOfContents>269.99</ValueOfContents><Country><![CDATA[Canada]]></Country><Container>RECTANGULAR</Container><Size>LARGE</Size><Width>10.00</Width><Length>15.00</Length><Height>4.50</Height><Girth>29.00</Girth></Package></IntlRateV2Request>"
    @carrier.expects(:commit).with(:world_rates, URI.encode(expected_request), false).returns(expected_request)
    @carrier.expects(:parse_rate_response)
    @carrier.find_rates(@locations[:beverly_hills], @locations[:ottawa], @packages[:american_wii], :test => true)
  end
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do USPS.new end
    assert_nothing_raised { USPS.new(:login => 'blah')}
  end

  def test_parse_international_rate_response
    fixture_xml = xml_fixture('usps/beverly_hills_to_ottawa_american_wii_rate_response')
    @carrier.expects(:commit).returns(fixture_xml)
    
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:ottawa],
        @packages[:american_wii],
        :test => true
      )
    rescue ResponseError => e
      e.response
    end
    
    expected_xml_hash = Hash.from_xml(fixture_xml)
    actual_xml_hash = Hash.from_xml(response.xml)
    
    assert_equal expected_xml_hash, actual_xml_hash
    
    assert_not_equal [],response.rates
    
    assert_equal [3420, 5835, 8525, 8525], response.rates.map(&:price)
    assert_equal [1, 2, 4, 12], response.rates.map(&:service_code).map(&:to_i).sort
    
    ordered_service_names = ["USPS Express Mail International",
      "USPS GXG Envelopes",
      "USPS Global Express Guaranteed (GXG)",
      "USPS Priority Mail International"]
    assert_equal ordered_service_names, response.rates.map(&:service_name).sort
  end
  
  def test_parse_max_dimension_sentences
    limits = {
      "Max. length 46\", width 35\", height 46\" and max. length plus girth 108\"" =>
        [{:length => 46.0, :width => 46.0, :height => 35.0, :length_plus_girth => 108.0}],
      "Max.length 42\", max. length plus girth 79\"" =>
        [{:length => 42.0, :length_plus_girth => 79.0}],
      "9 1/2\" X 12 1/2\"" =>
        [{:length => 12.5, :width => 9.5, :height => 0.75}, "Flat Rate Envelope"],
      "Maximum length and girth combined 108\"" =>
        [{:length_plus_girth => 108.0}],
      "USPS-supplied Priority Mail flat-rate envelope 9 1/2\" x 12 1/2.\" Maximum weight 4 pounds." =>
        [{:length => 12.5, :width => 9.5, :height => 0.75}, "Flat Rate Envelope"],
      "Max. length 24\", Max. length, height, depth combined 36\"" =>
        [{:length => 24.0, :length_plus_width_plus_height => 36.0}]
    }
    p = @packages[:book]
    limits.each do |sentence,hashes|
      dimensions = hashes[0].update(:weight => 50.0)
      service_node = build_service_node(
        :name => hashes[1],
        :max_weight => 50,
        :max_dimensions => sentence )
      @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions)
      @carrier.send(:package_valid_for_service, p, service_node)
    end
  
    service_node = build_service_node(
        :name => "flat-rate box",
        :max_weight => 50,
        :max_dimensions => "USPS-supplied Priority Mail flat-rate box. Maximum weight 20 pounds." )
    
    # should test against either kind of flat rate box:
    dimensions = [{:weight => 50.0, :length => 11.0, :width => 8.5, :height => 5.5}, # or...
      {:weight => 50.0, :length => 13.625, :width => 11.875, :height => 3.375}]
    @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions[0])
    @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions[1])
    @carrier.send(:package_valid_for_service, p, service_node)
    
  end
  
  def test_package_valid_for_max_dimensions
    p = Package.new(70 * 16, [10,10,10], :units => :imperial)
    limits = {:weight => 70.0, :length => 10.0, :width => 10.0, :height => 10.0, :length_plus_girth => 50.0, :length_plus_width_plus_height => 30.0}
    assert_equal true, @carrier.send(:package_valid_for_max_dimensions, p, limits)
    
    limits.keys.each do |key|
      dimensions = {key => (limits[key] - 1)}
      assert_equal false, @carrier.send(:package_valid_for_max_dimensions, p, dimensions)
    end
    
  end
  
  def test_strip_9_digit_zip_codes
    request = URI.decode(@carrier.send(:build_us_rate_request, @packages[:book], "90210-1234", "123456789"))
    assert !(request =~ /\>90210-1234\</)
    assert request =~ /\>90210\</
    assert !(request =~ /\>123456789\</)
    assert request =~ /\>12345\</
  end
  
  def test_maximum_weight
    assert Package.new(70 * 16, [5,5,5], :units => :imperial).mass == @carrier.maximum_weight
    assert Package.new((70 * 16) + 0.01, [5,5,5], :units => :imperial).mass > @carrier.maximum_weight
    assert Package.new((70 * 16) - 0.01, [5,5,5], :units => :imperial).mass < @carrier.maximum_weight
  end
  
  def test_updated_domestic_rate_name_format_with_unescaped_html
    mock_response = xml_fixture('usps/beverly_hills_to_new_york_book_rate_response')
    @carrier.expects(:commit).returns(mock_response)
    rates_response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:new_york],
      @packages[:book],
      :test => true
    )
    rate_names = [
      'USPS Express Mail',
      'USPS Express Mail Flat Rate Envelope',
      'USPS Express Mail Flat Rate Envelope Hold For Pickup',
      'USPS Express Mail Hold For Pickup',
      'USPS Express Mail Legal Flat Rate Envelope',
      'USPS Express Mail Legal Flat Rate Envelope Hold For Pickup',
      'USPS Express Mail Sunday/Holiday Delivery',
      'USPS Express Mail Sunday/Holiday Delivery Flat Rate Envelope',
      'USPS Express Mail Sunday/Holiday Delivery Legal Flat Rate Envelope',
      'USPS First-Class Mail Large Envelope',
      'USPS First-Class Mail Package',
      'USPS Library Mail',
      'USPS Media Mail',
      'USPS Parcel Post',
      'USPS Priority Mail',
      'USPS Priority Mail Flat Rate Envelope',
      'USPS Priority Mail Gift Card Flat Rate Envelope',
      'USPS Priority Mail Large Flat Rate Box',
      'USPS Priority Mail Legal Flat Rate Envelope',
      'USPS Priority Mail Medium Flat Rate Box',
      'USPS Priority Mail Padded Flat Rate Envelope',
      'USPS Priority Mail Small Flat Rate Box',
      'USPS Priority Mail Small Flat Rate Envelope',
      'USPS Priority Mail Window Flat Rate Envelope'
    ]
    assert_equal rate_names, rates_response.rates.collect(&:service_name).sort
  end

  def test_first_class_packages_with_mail_type
    @carrier.expects(:commit).returns(xml_fixture('usps/first_class_packages_with_mail_type_response'))
    
    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0,0),
        {
          :test => true,
          :service => :first_class,
          :first_class_mail_type => :parcel
        }
      )
    rescue ResponseError => e
      e.response
    end
    assert response.success?, response.message
  end

  def test_first_class_packages_without_mail_type
    @carrier.expects(:commit).returns(xml_fixture('usps/first_class_packages_without_mail_type_response'))

    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0,0),
        {
          :test => true,
          :service => :first_class
        }
      )
    rescue ResponseError => e
      assert_equal "Invalid First Class Mail Type.", e.message
    end
  end

  def test_first_class_packages_with_invalid_mail_type
    @carrier.expects(:commit).returns(xml_fixture('usps/first_class_packages_with_invalid_mail_type_response'))

    response = begin
      @carrier.find_rates(
        @locations[:beverly_hills], # imperial (U.S. origin)
        @locations[:new_york],
        Package.new(0,0),
        {
          :test => true,
          :service => :first_class,
          :first_class_mail_tpe => :invalid
        }
      )
    rescue ResponseError => e
      assert_equal "Invalid First Class Mail Type.", e.message
    end
  end

  def test_domestic_retail_rates
    mock_response = xml_fixture('usps/beverly_hills_to_new_york_book_commercial_base_rate_response')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:new_york],
      @packages.values_at(:book),
      :test => true
    )

    rates = Hash[response.rates.map {|rate| [rate.service_name, rate.price]}]

    assert_equal 0,rates["USPS First-Class Package Service"] #the "first class package service" is only available for commercial base shippers
    assert_equal 309,rates["USPS First-Class Mail Parcel"] #2013 retail 9oz first class parcel is $3.09
    assert_equal 695,rates["USPS Priority Mail"] #2013 1lb zone 8 priority retail is $6.95
  end

  def test_domestic_commercial_base_rates
    @carrier = USPS.new(fixtures(:usps).merge(:commercial_base => true))

    mock_response = xml_fixture('usps/beverly_hills_to_new_york_book_commercial_base_rate_response')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:new_york],
      @packages.values_at(:book),
      :test => true
    )

    rates = Hash[response.rates.map {|rate| [rate.service_name, rate.price]}]

    assert_equal 0,rates["USPS First-Class Mail Parcel"] #commercial base prices retail first class is unavailable. must ship as package service
    assert_equal 273,rates["USPS First-Class Package Service"] #the "first class package service" should be present for commerical base (instead of USPS First-Class Mail Parcel for retail rates)
    assert_equal 651,rates["USPS Priority Mail"] #2013 zone 8 commercial base price is 6.51, retail is 6.95
  end

  def test_intl_commercial_base_rates
    @carrier = USPS.new(fixtures(:usps).merge(:commercial_base => true))

    mock_response = xml_fixture('usps/beverly_hills_to_ottawa_american_wii_commercial_base_rate_response')
    @carrier.expects(:commit).returns(mock_response)

    response = @carrier.find_rates(
      @locations[:beverly_hills],
      @locations[:ottawa],
      @packages.values_at(:american_wii),
      :test => true
    )

    rates = Hash[response.rates.map {|rate| [rate.service_name, rate.price]}]

    assert_equal [4112, 6047, 7744, 7744], response.rates.map(&:price) #note these prices are higher than the normal/retail unit tests because the rates from that test is years older than from this test
  end
  
  private
  
  def build_service_node(options = {})
    XmlNode.new('Service') do |service_node|
      service_node << XmlNode.new('Pounds', options[:pounds] || "0")
      service_node << XmlNode.new('SvcCommitments', options[:svc_commitments] || "Varies")
      service_node << XmlNode.new('Country', options[:country] || "CANADA")
      service_node << XmlNode.new('ID', options[:id] || "3")
      service_node << XmlNode.new('MaxWeight', options[:max_weight] || "64")
      service_node << XmlNode.new('SvcDescription', options[:name] || "First-Class Mail International")
      service_node << XmlNode.new('MailType', options[:mail_type] || "Package")
      service_node << XmlNode.new('Postage', options[:postage] || "3.76")
      service_node << XmlNode.new('Ounces', options[:ounces] || "9")
      service_node << XmlNode.new('MaxDimensions', options[:max_dimensions].dup || "Max. length 24\", Max. length, height, depth combined 36\"")
    end.to_xml_element
  end
  
  def build_service_hash(options = {})
    {"Pounds"=> options[:pounds] || "0",
         "SvcCommitments"=> options[:svc_commitments] || "Varies",
         "Country"=> options[:country] || "CANADA",
         "ID"=> options[:id] || "3",
         "MaxWeight"=> options[:max_weight] || "64",
         "SvcDescription"=> options[:name] || "First-Class Mail International",
         "MailType"=> options[:mail_type] || "Package",
         "Postage"=> options[:postage] || "3.76",
         "Ounces"=> options[:ounces] || "9",
         "MaxDimensions"=> options[:max_dimensions] || 
          "Max. length 24\", Max. length, height, depth combined 36\""}
  end
end
