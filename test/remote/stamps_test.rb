require 'test_helper'

class StampsTest < Test::Unit::TestCase
  def setup
    @packages   = TestFixtures.packages
    @locations  = TestFixtures.locations
    @line_items = TestFixtures.line_items1
    @carrier    = Stamps.new(fixtures(:stamps).merge(test: true))
  end

  def test_valid_credentials
    assert @carrier.valid_credentials?
  end

  def test_account_info
    @account_info = @carrier.account_info

    assert_equal 'ActiveMerchant::Shipping::StampsAccountInfoResponse', @account_info.class.name
  end
end
