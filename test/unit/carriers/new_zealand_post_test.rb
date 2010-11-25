require 'test_helper'

class NewZealandPostTest < Test::Unit::TestCase

  def setup
    login = fixtures(:new_zealand_post)

    @carrier  = NewZealandPost.new(login)

    @response = xml_fixture('newzealandpost/example_response')
    # @bad_response = xml_fixture('newzealandpost/example_response_error')

    @origin      = {:postal_code => "6011"}
    @destination = {:postal_code => "6012"}
    @line_items  = [Package.new(400,
                                [25, 15, 2],
                                :description => "Edmonds Cookbook",
                                :units => :metric)]
  end

  def test_parse_response
  end

  def test_build_rectangular_request_params
    params = @carrier.send(:build_rectangular_request_params, @origin, @destination, @line_items)

    assert_equal '123', params[:api_key]
    assert_equal '25', params[:length]
    assert_equal '15', params[:thickness]
    assert_equal '2', params[:height]
    assert_equal '0.4', params[:weight]
    assert_equal '6011', params[:postcode_src]
    assert_equal '6012', params[:postcode_dest]
  end

end
