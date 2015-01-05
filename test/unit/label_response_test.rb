require 'test_helper'

class LabelResponseTest < Minitest::Test
  include ActiveShipping::Test::Fixtures

  def test_build_label_from_xml_response
    str      = xml_fixture('ups/shipment_accept_response')
    mapping  = Hash.from_xml(str).values.first
    response = LabelResponse.new(true, nil, mapping)

    assert_equal 1, response.labels.count
    assert_equal '1ZA03R691591538440', response.labels.first[:tracking_number]
    assert response.labels.first[:image]
  end
end
