require File.dirname(__FILE__) + '/../../test_helper'

class ShipwireTest < Test::Unit::TestCase
  
  def setup
    @packages               = TestFixtures.packages
    @locations              = TestFixtures.locations
    @carrier                = Shipwire.new(
                                :login => 'login',
                                :password => 'password'
                              )

    @rate_response = xml_fixture('ups/shipment_from_tiger_direct')
  end
  
  def test_truth
    assert true
  end
  
  #def test_add_origin_and_destination_data_to_shipment_events_where_appropriate
  #  Shipwire.any_instance.expects(:commit).returns(@tracking_response)
  #  response = @carrier.find_tracking_info('1Z5FX0076803466397')
  #  assert_equal '175 AMBASSADOR', response.shipment_events.first.location.address1
  #  assert_equal 'K1N5X8', response.shipment_events.last.location.postal_code
  #end
  #
  #def test_response_parsing
  #  mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
  #  Shipwire.any_instance.expects(:commit).returns(mock_response)
  #  response = @carrier.find_rates( @locations[:beverly_hills],
  #                                  @locations[:real_home_as_residential],
  #                                  @packages.values_at(:chocolate_stuff))
  #  assert_equal [ "Shipwire Ground",
  #                 "Shipwire Three-Day Select",
  #                 "Shipwire Second Day Air",
  #                 "Shipwire Next Day Air Saver",
  #                 "Shipwire Next Day Air Early A.M.",
  #                 "Shipwire Next Day Air"], response.rates.map(&:service_name)
  #  assert_equal [992, 2191, 3007, 5509, 9401, 6124], response.rates.map(&:price)
  #end
  #
  #def test_xml_logging_to_file
  #  mock_response = xml_fixture('ups/test_real_home_as_residential_destination_response')
  #  Shipwire.any_instance.expects(:commit).times(2).returns(mock_response)
  #  RateResponse.any_instance.expects(:log_xml).with({:name => 'test', :path => '/tmp/logs'}).times(1).returns(true)
  #  response = @carrier.find_rates( @locations[:beverly_hills],
  #                                  @locations[:real_home_as_residential],
  #                                  @packages.values_at(:chocolate_stuff),
  #                                  :log_xml => {:name => 'test', :path => '/tmp/logs'})
  #  response = @carrier.find_rates( @locations[:beverly_hills],
  #                                  @locations[:real_home_as_residential],
  #                                  @packages.values_at(:chocolate_stuff))
  #end
  #
  #def test_maximum_weight
  #  assert Package.new(150 * 16, [5,5,5], :units => :imperial).mass == @carrier.maximum_weight
  #  assert Package.new((150 * 16) + 0.01, [5,5,5], :units => :imperial).mass > @carrier.maximum_weight
  #  assert Package.new((150 * 16) - 0.01, [5,5,5], :units => :imperial).mass < @carrier.maximum_weight
  #end
end