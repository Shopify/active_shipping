require 'test_helper'

class RemoteUSPSReturnsTest < Minitest::Test
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    begin
      creds = credentials(:usps_returns)
      @carrier = USPSReturns.new
      @external_return_label_request =
        ExternalReturnLabelRequest.from_hash(
          :merchant_account_id => creds[:merchant_account_id],
          :mid => creds[:mid],
          :customer_name => 'Joe Dirt',
          :customer_address1 => '122 W Hudson St',
          :customer_address2 => 'Unit 2',
          :customer_city => 'New York',
          :customer_state => 'NY',
          :customer_zipcode => '10013',
          :label_format => 'No Instructions',
          :label_definition => '4X6',
          :recipient_bcc => 'test@gmail.com',
          :service_type_code => '020',
          :address_override_notification => 'true',
          :address_validation => 'true',
          :call_center_or_self_service => 'Customer'
        )
    rescue NoCredentialsFound => e
      skip(e.message)
    end
  end

  def test_external_return_label_request
    assert_silent do
      @carrier.external_return_label_request(@external_return_label_request, :test => true)
    end
  end

  def test_external_return_label_with_bad_account
    assert_raises ResponseError do
      @external_return_label_request.merchant_account_id = "1234"
      @carrier.external_return_label_request(@external_return_label_request, :test => true)
    end
  end

  def test_external_return_label_with_address_validation_false
    assert_silent do
      @external_return_label_request.address_validation = false
      @carrier.external_return_label_request(@external_return_label_request, :test => true)
    end
  end

  def test_external_return_label_with_address_validation_false_and_bad_address
    assert_silent do
      @external_return_label_request.address_validation = false
      @external_return_label_request.customer_state = 'NJ'
      @external_return_label_request.customer_zipcode = '08829'
      @carrier.external_return_label_request(@external_return_label_request, :test => true)
    end
  end

  def test_external_return_label_with_address_validation_true_and_bad_address
    assert_raises ResponseError do
      @external_return_label_request.address_validation = true
      @external_return_label_request.customer_state = 'NJ'
      @external_return_label_request.customer_zipcode = '08829'
      @carrier.external_return_label_request(@external_return_label_request, :test => true)
    end
  end

end
