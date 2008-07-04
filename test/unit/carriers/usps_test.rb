require File.dirname(__FILE__) + '/../../test_helper'

class USPSTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @packages               = fixtures(:packages)
    @locations              = fixtures(:locations)
    @carrier                = USPS.new(:login => 'login')
    @international_rate_responses = {
      :vanilla => xml_fixture('usps/beverly_hills_to_ottawa_book_rate_response')
    }

  end
  
  # TODO: test_parse_domestic_rate_response
  # TODO: test_build_us_rate_request
  # TODO: test_build_world_rate_request
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do USPS.new end
    assert_nothing_raised { USPS.new(:login => 'blah')}
  end

  def test_parse_international_rate_response
    fixture_xml = @international_rate_responses[:vanilla]
    USPS.any_instance.expects(:commit).returns(fixture_xml)
    
    response = begin
      @carrier.find_rates( @locations[:beverly_hills], # imperial (U.S. origin)
                                  @locations[:ottawa],
                                  @packages[:book],
                                  :test => true)
    rescue ResponseError => e
      e.response
    end
    
    
    expected_xml_hash = Hash.from_xml(fixture_xml)
    actual_xml_hash = Hash.from_xml(response.xml)
    
    assert_equal expected_xml_hash, actual_xml_hash
    
    assert_not_equal [],response.rates
    
    assert_equal ["3", "2", "9", "1", "7", "6", "4"], response.rates.map(&:service_code)
    
    ordered_service_names = ["USPS First-Class Mail International",
                             "USPS Priority Mail International",
                             "USPS Priority Mail International Flat Rate Box",
                             "USPS Express Mail International (EMS)",
                             "USPS Global Express Guaranteed Non-Document Non-Rectangular",
                             "USPS Global Express Guaranteed Non-Document Rectangular",
                             "USPS Global Express Guaranteed"]
    assert_equal ordered_service_names, response.rates.map(&:service_name)
    
    
    assert_equal [376, 1600, 2300, 2325, 4100, 4100, 4100], response.rates.map(&:total_price)
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
      service_hash = build_service_hash(
        :name => hashes[1],
        :max_weight => 50,
        :max_dimensions => sentence )
      @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions)
      @carrier.send(:package_valid_for_service, p, service_hash)
    end
  
    service_hash = build_service_hash(
        :name => "flat-rate box",
        :max_weight => 50,
        :max_dimensions => "USPS-supplied Priority Mail flat-rate box. Maximum weight 20 pounds." )
    
    # should test against either kind of flat rate box:
    dimensions = [{:weight => 50.0, :length => 11.0, :width => 8.5, :height => 5.5}, # or...
      {:weight => 50.0, :length => 13.625, :width => 11.875, :height => 3.375}]
    @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions[0])
    @carrier.expects(:package_valid_for_max_dimensions).with(p, dimensions[1])
    @carrier.send(:package_valid_for_service, p, service_hash)
    
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
  
  private
  
  def build_service_hash(options = {})
    {"Pounds"=> options[:pounds] || "0",                                                                         # 8
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