require File.dirname(__FILE__) + '/../../test_helper'

class FedExTest < Test::Unit::TestCase
  def setup
    @packages               = TestFixtures.packages
    @locations              = TestFixtures.locations
    @carrier                = FedEx.new(
                                :login => 'login',
                                :password => 'password'
                              )
    @tracking_response = xml_fixture('fedex/domestic_shipment')
    @intl_tracking_response = xml_fixture('fedex/shipment_to_canada')
  end
  
  def test_initialize_options_requirements
    assert_raises ArgumentError do FedEx.new end
    assert_raises ArgumentError do FedEx.new(:login => '999999999') end
    assert_raises ArgumentError do FedEx.new(:password => '7777777') end
    assert_nothing_raised { FedEx.new(:login => '999999999', :password => '7777777')}
  end
  
  def test_invalid_recipient_country
    @carrier.expects(:commit).returns(xml_fixture('fedex/invalid_recipient_country_response'))

    begin
      @carrier.find_rates(
        @locations[:ottawa],                                
        @locations[:beverly_hills],            
        @packages.values_at(:book, :wii)
      )
    rescue ResponseError => e
      assert_equal "FedEx Error Code: 61451: Invalid recipient country", e.message
    end
  end
  
  def test_no_rates_response
    @carrier.expects(:commit).returns(xml_fixture('fedex/empty_response'))

    begin
      response = @carrier.find_rates(
        @locations[:ottawa],                                
        @locations[:beverly_hills],            
        @packages.values_at(:book, :wii)
      )
    rescue ResponseError => e
      assert_equal "No shipping rates could be found for the destination address", e.message
    end
  end
  
  def test_find_tracking_info_should_return_a_tracking_response
    @carrier.expects(:commit).returns(@tracking_response)
    assert_instance_of ActiveMerchant::Shipping::TrackingResponse, @carrier.find_tracking_info('077973360390581')
  end
  
  def test_find_tracking_info_should_parse_response_into_correct_number_of_shipment_events
    @carrier.expects(:commit).returns(@intl_tracking_response)
    response = @carrier.find_tracking_info('931519441327', :carrier_code => 'fedex_express')
    assert_equal 14, response.shipment_events.size
  end
  
  def test_find_tracking_info_should_return_shipment_events_in_ascending_chronological_order
    @carrier.expects(:commit).returns(@intl_tracking_response)
    response = @carrier.find_tracking_info('931519441327', :carrier_code => 'fedex_express')
    assert_equal response.shipment_events.map(&:time).sort, response.shipment_events.map(&:time)
  end
  
  def test_building_request_and_parsing_response
    mock_request = xml_fixture('fedex/ottawa_to_beverly_hills_rate_request')
    mock_response = xml_fixture('fedex/ottawa_to_beverly_hills_rate_response')
    Time.any_instance.expects(:strftime).with("%Y-%m-%d").returns('2009-02-05')
    @carrier.expects(:commit).with {|request, test_mode| Hash.from_xml(request) == Hash.from_xml(mock_request) && test_mode}.returns(mock_response)
    response = @carrier.find_rates( @locations[:ottawa],
                                    @locations[:beverly_hills],
                                    @packages.values_at(:book, :wii),
                                    :test => true)
    assert_equal [ "FedEx International Priority",
                   "FedEx International Economy",
                   "FedEx International First",
                   "FedEx Ground"], response.rates.map(&:service_name)
    assert_equal [12243, 8084, 18050, 3614], response.rates.map(&:price)
    
    assert response.success?, response.message
    assert_instance_of Hash, response.params
    assert_instance_of String, response.xml
    assert_instance_of Array, response.rates
    assert_not_equal [], response.rates
    
    rate = response.rates.first
    assert_equal 'FedEx', rate.carrier
    assert_equal 'USD', rate.currency
    assert_instance_of Fixnum, rate.total_price
    assert_instance_of Fixnum, rate.price
    assert_instance_of String, rate.service_name
    assert_instance_of String, rate.service_code
    assert_instance_of Array, rate.package_rates
    assert_equal @packages.values_at(:book, :wii), rate.packages
    
    package_rate = rate.package_rates.first
    assert_instance_of Hash, package_rate
    assert_instance_of Package, package_rate[:package]
    assert_nil package_rate[:rate]
  end
end