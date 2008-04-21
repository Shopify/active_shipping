require File.dirname(__FILE__) + '/../test_helper'

class ResponseTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  
  def setup

  end

  def test_initialize
    response = nil
    assert_nothing_raised do
      response = Response.new(true, "success!", {:rate => 'Free!'}, :rates => [stub(:service_name => 'Free!', :total_price => 0)], :xml => "<rate>Free!</rate>")
    end
    
  end
end