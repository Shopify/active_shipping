require 'test_helper'

class RemoteUPSSurepostTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @options = credentials(:ups_surepost).merge(:test => true)
    @carrier = UPS.new(@options)
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_obtain_surpost_less_than_one_lb_shipping_label
    response = @carrier.create_shipment(
      location_fixtures[:beverly_hills],
      location_fixtures[:new_york_with_name],
      package_fixtures.values_at(:small_half_pound),
      {
        :test => true,
        :service_code => "92"
      }
    )

    assert response.success?

    # All behavior specific to how a LabelResponse behaves in the
    # context of UPS label data is a matter for unit tests.  If
    # the data changes substantially, the create_shipment
    # ought to raise an exception and this test will fail.
    assert_instance_of ActiveShipping::LabelResponse, response
  end
end
