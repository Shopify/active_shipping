require 'test_helper'
require 'pp'
class CanadaPostPwsRatingTest < Test::Unit::TestCase

  def setup
    login = fixtures(:canada_post_pws)
    
    # 100 grams, 93 cm long, 10 cm diameter, cylinders have different volume calculations
    @pkg1 = Package.new(25, [93,10], :cylinder => true)
    # 7.5 lbs, times 16 oz/lb., 15x10x4.5 inches, not grams, not centimetres
    @pkg2 = Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial)
    
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

    @dest_params = {
      :name     => "Frank White",
      :address1 => '999 Wiltshire Blvd',
      :city     => 'Beverly Hills', 
      :state    => 'CA', 
      :country  => 'US', 
      :zip      => '90210'
    }
    @dest = Location.new(@dest_params)

    @cp = CanadaPostPWS.new(login)
    @cp.logger = Logger.new(STDOUT)
    @french_cp = CanadaPostPWS.new(login.merge(:language => 'fr'))

    @default_options = {:customer_number => '123456'}
  end
  
  # rating

  def test_language_header
    assert_equal 'fr-CA', @french_cp.language
    assert_equal 'en-CA', @cp.language
  end

  def test_find_rates
    response = xml_fixture('canadapost_pws/rates_info')
    expected_headers = {
      'Authorization'   => "Basic YzcwZGE1ZWQ1YTBkMmMzMjpiNDM4ZmY3ZDllNTgxY2QwZDJlZGJl\n",
      'Accept-Language' => 'en-CA',
      'Accept'          => 'application/vnd.cpc.ship.rate+xml',
      'Content-Type'    => 'application/vnd.cpc.ship.rate+xml'
    }
    # TODO: with(anything, anything, expected_headers) won't pass for some reason... how does .with do equality?
    CanadaPostPWS.any_instance.expects(:ssl_post).with(anything, anything, anything).returns(response)

    rates_response = @cp.find_rates(@home_params, @dest_params, [@pkg1, @pkg2], @default_options)
    
    assert_equal 4, rates_response.rates.size
    rate = rates_response.rates.first
    assert_equal RateEstimate, rate.class
    assert_equal "Canada Post PWS", rate.carrier
    assert_equal @home.to_s, Location.new(rate.origin).to_s
    assert_equal @dest.to_s, Location.new(rate.destination).to_s
  end

  def test_find_rates_with_error
    response = xml_fixture('canadapost_pws/rates_info_error')
    CanadaPostPWS.any_instance.expects(:ssl_post).returns(response)

    exception = assert_raises ActiveMerchant::Shipping::ResponseError do 
      @cp.find_rates(@home_params, @dest_params, [@pkg1, @pkg2], @default_options)
    end
    
    assert_equal "You cannot mail on behalf of the requested customer.", exception.message
  end

  # build rates

  def test_build_rates_request
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], @default_options)
    doc = Nokogiri::HTML(xml)

    assert_equal @default_options[:customer_number], doc.xpath('//customer-number').first.content
    assert_equal 'K1P1J1', doc.xpath('//origin-postal-code').first.content
    assert_equal 'united-states', doc.xpath('//destination').children.first.name
    assert !doc.xpath('//parcel-characteristics').empty?
    assert_equal "3.427", doc.xpath('//parcel-characteristics//weight').first.content
  end

  def test_build_rates_request_domestic
    @dest_params = {       
      :name        => "John Smith", 
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "123 Oak St.",
      :city        => 'Vanncouver', 
      :province    => 'BC', 
      :country     => 'CA', 
      :postal_code => 'V5J 1J1'
    }
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], @default_options)
    doc = Nokogiri::HTML(xml)

    assert_equal 'K1P1J1', doc.xpath('//origin-postal-code').first.content
    assert_equal 'domestic', doc.xpath('//destination').children.first.name
    assert_equal 'V5J1J1', doc.xpath('//destination//postal-code').first.content
  end

  def test_build_rates_request_international
    @dest_params = {       
      :name        => "John Smith", 
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "123 Tokyo St",
      :city        => 'Tokyo', 
      :country     => 'JP'
    }
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], @default_options)
    doc = Nokogiri::HTML(xml)

    assert_equal 'K1P1J1', doc.xpath('//origin-postal-code').first.content
    assert_equal 'international', doc.xpath('//destination').children.first.name
    assert_equal 'JP', doc.xpath('//destination//country-code').first.content
  end

  def test_build_rates_request_with_cod_option
    opts = @default_options.merge({:cod => true, :cod_amount => 12.05})
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal 'COD', doc.xpath('//options/option').children.first.content
    assert_equal '12.05', doc.xpath('//options/option').children.last.content
  end

  def test_build_rates_request_with_signature_option
    opts = @default_options.merge({:signature_required => true})
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal 'SO', doc.xpath('//options/option').children.first.content
  end

  def test_build_rates_request_with_insurance_option
    opts = @default_options.merge({:insurance => true, :insurance_amount => 122.05})
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal 'COV', doc.xpath('//options/option').children.first.content
    assert_equal '122.05', doc.xpath('//options/option').children.last.content
  end

  def test_build_rates_request_with_other_options
    opts = @default_options.merge({:pa18 => true, :pa19 => true, :hfp => true, :dns => true, :lad => true})
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1, @pkg2], opts)
    doc = Nokogiri::HTML(xml)

    options = doc.xpath('//options/option').map {|o| o.content }.sort
    assert_equal ["PA18", "PA19", "HFP", "DNS", "LAD"].sort, options
  end

  def test_build_rates_request_with_single_item
    opts = @default_options
    xml = @cp.build_rates_request(@home_params, @dest_params, [@pkg1], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal '0.025', doc.xpath('//parcel-characteristics/weight').first.content
  end

  def test_build_rates_request_with_mailing_tube
    pkg = Package.new(25, [93,10], :cylinder => true)
    opts = @default_options
    xml = @cp.build_rates_request(@home_params, @dest_params, [pkg], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal 'true', doc.xpath('//parcel-characteristics/mailing-tube').first.content
  end

  def test_build_rates_request_with_oversize
    pkg = Package.new(25, [93,10], :oversized => true)
    opts = @default_options
    xml = @cp.build_rates_request(@home_params, @dest_params, [pkg], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal 'true', doc.xpath('//parcel-characteristics/oversized').first.content
  end

  def test_build_rates_request_with_unpackaged
    pkg = Package.new(25, [93,10], :unpackaged => true)
    opts = @default_options
    xml = @cp.build_rates_request(@home_params, @dest_params, [pkg], opts)
    doc = Nokogiri::HTML(xml)

    assert_equal 'true', doc.xpath('//parcel-characteristics/unpackaged').first.content
  end

  # parse response

  def test_parse_rates_response
    body = xml_fixture('canadapost_pws/rates_info')
    rates_response = @cp.parse_rates_response(body, @home, @dest)

    assert_equal 4, rates_response.rates.count
    rate = rates_response.rates.first
    assert_equal "DOM.EP", rate.service_code
    assert_equal 'Expedited Parcel', rate.service_name
    assert_equal @home, rate.origin
    assert_equal @dest, rate.destination
    assert_equal 1301, rate.total_price    
  end

  def test_parse_rates_response_with_invalid_response_raises
    body = xml_fixture('canadapost_pws/rates_info_error')
    exception = assert_raises ActiveMerchant::Shipping::ResponseError do
      @response = @cp.parse_rates_response(body, @home, @dest)
    end
    assert_equal "No Quotes", exception.message
  end

end
