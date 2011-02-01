require 'test_helper'

class NewZealandPostTest < Test::Unit::TestCase

  def setup
    @carrier  = NewZealandPost.new(:key => '123')

    @response = xml_fixture('newzealandpost/example_response')
    @bad_response = xml_fixture('newzealandpost/example_response_error')

    @origin      = Location.new(:postal_code => "6011")
    @destination = Location.new(:postal_code => "6012")
    @line_items  = [Package.new(400,
                                [25, 15, 2],
                                :description => "Edmonds Cookbook",
                                :units => :metric),
                    Package.new(300,
                                [85, 55],
                                :cylinder => true,
                                :description => "Movie Poster",
                                :units => :metric)]
  end

  def test_build_request_rectangular
    params = @carrier.send(:build_rectangular_request_params, @origin, @destination, @line_items[0])

    assert_equal '123', params[:api_key]
    assert_equal '250', params[:length]
    assert_equal '150', params[:thickness]
    assert_equal '20', params[:height]
    assert_equal '0.4', params[:weight]
    assert_equal '6011', params[:postcode_src]
    assert_equal '6012', params[:postcode_dest]
  end

  def test_build_request_cylinder
    params = @carrier.send(:build_tube_request_params, @origin, @destination, @line_items[1])

    assert_equal '123', params[:api_key]
    assert_equal '850', params[:length]
    assert_equal '550', params[:diameter]
    assert_equal '0.3', params[:weight]
    assert_equal '6011', params[:postcode_src]
    assert_equal '6012', params[:postcode_dest]
  end


  def test_parse_response
    @carrier.expects(:ssl_get).returns(@response)
    rate_response = @carrier.find_rates(@origin, @destination, @line_items[0])
    assert_not_nil rate_response
    assert_equal 2, rate_response.rates.size
    
    # test first element
    
    first_element = rate_response.rates.find{|rate| rate.service_code == 'PCBXT' }
    assert_equal 550, first_element.price
    assert_equal 'Parcel Post Tracked Zonal', first_element.service_name
    
    # test last element
    last_element = first_element = rate_response.rates.find{|rate| rate.service_code == 'PCB3C4' }
    assert_equal 540, last_element.price
    assert_equal 'Parcel Post Tracked', last_element.service_name
  end

  def test_response_success_with_successful_response
    xml = REXML::Document.new(@response)
    assert_equal true, @carrier.send(:response_success?, xml)
  end

  def test_response_success_with_bad_response
    xml = REXML::Document.new(@bad_response)
    assert_equal false, @carrier.send(:response_success?, xml)
  end

  def test_response_message_with_successful_response
    xml = REXML::Document.new(@response)
    assert_equal 'Success', @carrier.send(:response_message, xml)
  end

  def test_response_message_with_bad_response
    xml = REXML::Document.new(@bad_response)
    assert_equal 'weight Must be less than 25 Kg', @carrier.send(:response_message, xml)
  end
end
