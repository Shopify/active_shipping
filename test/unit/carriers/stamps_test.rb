require 'test_helper'

class StampsTest < Test::Unit::TestCase
  def setup
    @packages = TestFixtures.packages
    @locations = TestFixtures.locations
    @carrier   = Stamps.new(integration_id: 'i', username: 'u', password: 'p')
    @items = [ { :sku => 'AF0001', :quantity => 1 }, { :sku => 'AF0002', :quantity => 2 } ]
    @authentication_response = xml_fixture('stamps/authenticate_user_response')
  end

  def test_authenticate_user
    response_chain(xml_fixture('stamps/get_account_info_response'))
    @carrier.account_info
  end

  def test_account_info
    response_chain(xml_fixture('stamps/get_account_info_response'))

    account_info = @carrier.account_info

    assert_equal 'ActiveMerchant::Shipping::StampsAccountInfoResponse', account_info.class.name

    assert_equal '1234567', account_info.customer_id
    assert_equal '1029384756', account_info.meter_number
    assert_equal '7654321', account_info.user_id

    assert_equal '123.45', account_info.available_postage
    assert_equal '543.21', account_info.control_total
    assert_equal '250', account_info.max_postage_balance

    assert_equal 'Los Angeles', account_info.lpo.city
    assert_equal 'CA', account_info.lpo.state
    assert_equal '90066', account_info.lpo.zip

    assert_equal true, account_info.can_print_shipping?
    assert_equal true, account_info.can_use_cost_codes?
    assert_equal true, account_info.can_use_hidden_postage?
    assert_equal true, account_info.can_purchase_sdc_insurance?
    assert_equal true, account_info.can_print_memo?
    assert_equal true, account_info.can_print_international?
    assert_equal true, account_info.can_purchase_postage?
    assert_equal true, account_info.can_edit_cost_codes?
    assert_equal false, account_info.must_use_cost_codes?
    assert_equal true, account_info.can_view_online_reports?

    assert_equal '987.65', account_info.per_print_limit
  end

  private

  def response_chain(primary_response)
    @carrier.expects(:ssl_post).twice.returns(@authentication_response, primary_response)
  end
end
