require 'test_helper'

class USPSReturnsTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  attr_reader :carrier

  def setup
    @carrier = USPSReturns.new
  end

  def test_external_return_label_response_failure_should_raise_exception
    @carrier.expects(:commit).returns(xml_fixture('usps_returns/external_return_label_response_failure'))
    assert_raises ResponseError do
      @carrier.external_return_label_request(Nokogiri::XML({}))
    end
  end

  def test_external_return_label_errors
    response = Nokogiri::XML(xml_fixture('usps_returns/external_return_label_response_failure'))
    errors = @carrier.send(:external_return_label_errors, response)
    assert_equal errors.length > 0, true
  end

  def test_parse_external_return_label_response_raises_error
    response = xml_fixture('usps_returns/external_return_label_response_failure')
    assert_raises ResponseError do
      @carrier.send(:parse_external_return_label_response, response)
    end
  end

  def test_parse_external_return_label_response_returns_object
    response = xml_fixture('usps_returns/external_return_label_response')

    assert_equal @carrier.send(:parse_external_return_label_response, response).is_a?(ExternalReturnLabelResponse), true
    assert_equal @carrier.send(:parse_external_return_label_response, response).tracking_number, "9202090140694100000410"
    assert_equal @carrier.send(:parse_external_return_label_response, response).postal_routing, "420770739921"
  end

  def test_external_return_label_response_should_return_external_label_response
    @carrier.expects(:commit).returns(xml_fixture('usps_returns/external_return_label_response'))
    assert_equal @carrier.external_return_label_request(Nokogiri::XML({})).tracking_number, "9202090140694100000410"
  end

end
