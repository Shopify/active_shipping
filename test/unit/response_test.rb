require 'test_helper'

class ResponseTest < ActiveSupport::TestCase
  test "#initialize for a successful response" do
    response = RateResponse.new(
      true,
      "success!",
      { rate: 'Free!' },
      rates: [ stub(service_name: 'Free!', total_price: 0) ],
      xml: "<rate>Free!</rate>"
    )
    assert_predicate response, :success?
  end

  test "#initialize for a failed response raises ResponseError" do
    assert_raises(ActiveShipping::ResponseError) do
      RateResponse.new(
        false,
        "fail!",
        { rate: 'Free!' },
        rates: [ stub(service_name: 'Free!', total_price: 0) ],
        xml: "<rate>Free!</rate>"
      )
    end
  end

  test "#initialize doesn't raise when you pass in allow_failure" do
    response = RateResponse.new(
      false,
      "fail!",
      { rate: 'Free!' },
      rates: [ stub(service_name: 'Free!', total_price: 0) ],
      xml: "<rate>Free!</rate>",
      allow_failure: true,
    )
    refute_predicate response, :success?
  end
end
