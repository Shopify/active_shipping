require 'test_helper'

class NewZealandPostTest < Test::Unit::TestCase

  def setup
    login = fixtures(:new_zealand_post)

    @carrier  = NewZealandPost.new(login)

    @response = xml_fixture('newzealandpost/example_response')
    @bad_response = xml_fixture('newzealandpost/example_response_error')

    @origin      = {:postal_code => "6011"}
    @destination = {:postal_code => "6012"}
    @line_items  = [Package.new(400,
                                [25, 15, 2],
                                :description => "Edmonds Cookbook",
                                :units => :metric)]
  end

  def test_build_request_rectangular
    params = @carrier.send(:build_rectangular_request_params, @origin, @destination, @line_items)

    assert_equal '123', params[:api_key]
    assert_equal '25', params[:length]
    assert_equal '15', params[:thickness]
    assert_equal '2', params[:height]
    assert_equal '0.4', params[:weight]
    assert_equal '6011', params[:postcode_src]
    assert_equal '6012', params[:postcode_dest]
  end

  def test_build_request_cyclinder
  end

  def test_build_request_multiple_rectangular
  end

  def test_parse_response
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
