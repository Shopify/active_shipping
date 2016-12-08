require 'test_helper'

class ResponseTest < ActiveSupport::TestCase
  def test_initialize_success
    response = RateResponse.new(true, "success!", {:rate => 'Free!'}, :rates => [stub(:service_name => 'Free!', :total_price => 0)], :xml => "<rate>Free!</rate>")
    assert response.success?
  end

  def test_initialize_failure
    assert_raises(ActiveShipping::ResponseError) do
      RateResponse.new(false, "fail!", {:rate => 'Free!'}, :rates => [stub(:service_name => 'Free!', :total_price => 0)], :xml => "<rate>Free!</rate>")
    end
  end

  def test_initialize_failure_no_raise
    response = RateResponse.new(false, "fail!", {:rate => 'Free!'}, :rates => [stub(:service_name => 'Free!', :total_price => 0)], :xml => "<rate>Free!</rate>", :allow_failure => true)
    refute response.success?
  end
end
