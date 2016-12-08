require 'test_helper'

class RemoteCanadaPostPWSTest < ActiveSupport::TestCase
  # All remote tests require Canada Post development environment credentials
  include ActiveShipping::Test::Credentials
  include ActiveShipping::Test::Fixtures

  def setup
    @login = credentials(:canada_post_pws)
    refute @login.key?(:platform_id), "The 'canada_post_pws' credentials should NOT include a platform ID"

    # 1000 grams, 93 cm long, 10 cm diameter, cylinders have different volume calculations
    @pkg1 = Package.new(1000, [93, 10, 10], :value => 10.00)

    @line_item1 = line_item_fixture

    @shipping_opts1 = { :dc => true, :cov => true, :cov_amount => 100.00, :aban => true }

    @home_params = {
      :name        => "John Smith",
      :company     => "test",
      :phone       => "613-555-1212",
      :address1    => "123 Elm St.",
      :city        => 'Ottawa',
      :province    => 'ON',
      :country     => 'CA',
      :postal_code => 'K1P 1J1'
    }
    @home = Location.new(@home_params)

    @dom_params = {
      :name        => "John Smith Sr.",
      :company     => "",
      :phone       => '123-123-1234',
      :address1    => "5500 Oak Ave",
      :city        => 'Vancouver',
      :province    => 'BC',
      :country     => 'CA',
      :postal_code => 'V5J 2T4'
    }

    @dest_params = {
      :name     => "Frank White",
      :phone    => '123-123-1234',
      :address1 => '999 Wiltshire Blvd',
      :city     => 'Beverly Hills',
      :state    => 'CA',
      :country  => 'US',
      :zip      => '90210'
    }
    @dest = Location.new(@dest_params)

    @dom_params = {
      :name        => "Mrs. Smith",
      :company     => "",
      :phone       => "604-555-1212",
      :address1    => "5000 Oak St.",
      :address2    => "",
      :city        => 'Vancouver',
      :province    => 'BC',
      :country     => 'CA',
      :postal_code => 'V5J 2N2'
    }

    @intl_params = {
      :name        => "Mrs. Yamamoto",
      :company     => "",
      :phone       => "011-123-123-1234",
      :address1    => "123 Yokohama Road",
      :address2    => "",
      :city        => 'Tokyo',
      :province    => '',
      :country     => 'JP'
    }

    @cp = CanadaPostPWS.new(@login.merge(:endpoint => "https://ct.soa-gw.canadapost.ca/"))
    @cp.logger = Logger.new(StringIO.new)

    @customer_number = @login[:customer_number]

    @DEFAULT_RESPONSE = {
      :shipping_id => "406951321983787352",
      :tracking_number => "123456789012",
      :label_url => "https://ct.soa-gw.canadapost.ca/ers/artifact/#{@login[:api_key]}/20238/0"
    }
  rescue NoCredentialsFound => e
    skip(e.message)
  end

  def test_rates
    opts = {:customer_number => @customer_number}
    rate_response = @cp.find_rates(@home_params, @dom_params, [@pkg1], opts)
    assert_kind_of ActiveShipping::RateResponse, rate_response
    assert_kind_of ActiveShipping::RateEstimate, rate_response.rates.first
  end

  def test_rates_with_invalid_customer_raises_exception
    opts = {:customer_number => "0000000000", :service => "DOM.XP"}
    assert_raises(ResponseError) do
      @cp.find_rates(@home_params, @dom_params, [@pkg1], opts)
    end
  end

  def test_tracking
    pin = "1371134583769923" # valid pin
    response = @cp.find_tracking_info(pin, {})
    assert_equal 'Xpresspost', response.service_name
    assert response.expected_date.is_a?(Date)
    assert response.customer_number
    assert_equal 13, response.shipment_events.count
  end

  def test_tracking_when_no_tracking_info_raises_exception
    pin = "4442172020196022" # valid pin

    error = assert_raises(ActiveShipping::ResponseError) do
      @cp.find_tracking_info(pin, {})
    end

    assert_match /No Tracking/, error.message
  end

  def test_create_shipment
    skip "Failing with 'Contract Number is a required field' after API change, skipping because no clue how to fix, might need different creds"
    opts = {:customer_number => @customer_number, :service => "DOM.XP"}
    response = @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)
    assert_kind_of CPPWSShippingResponse, response
    assert_match /\A\d{17}\z/, response.shipping_id
    assert_equal "123456789012", response.tracking_number
    assert_match "https://ct.soa-gw.canadapost.ca/ers/artifact/", response.label_url
    assert_match @login[:api_key], response.label_url
  end

  def test_create_shipment_with_options
    skip "Failing with 'Contract Number is a required field' after API change, skipping because no clue how to fix, might need different creds"
    opts = {:customer_number => @customer_number, :service => "USA.EP"}.merge(@shipping_opts1)
    response = @cp.create_shipment(@home_params, @dest_params, @pkg1, @line_item1, opts)

    assert_kind_of CPPWSShippingResponse, response
    assert_match /\A\d{17}\z/, response.shipping_id
    assert_equal "123456789012", response.tracking_number
    assert_match "https://ct.soa-gw.canadapost.ca/ers/artifact/", response.label_url
    assert_match @login[:api_key], response.label_url
  end

  def test_retrieve_shipping_label
    skip "Failing with 'Contract Number is a required field' after API change, skipping because no clue how to fix, might need different creds"
    opts = {:customer_number => @customer_number, :service => "DOM.XP"}
    shipping_response = @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)

    # Looks like it takes Canada Post some time to actually generate the PDF.
    response = nil
    10.times do
      response = @cp.retrieve_shipping_label(shipping_response)
      break unless response == ""
      sleep(0.5)
    end

    assert_equal "%PDF", response[0...4]
  end

  def test_create_shipment_with_invalid_customer_raises_exception
    skip "Failing with 'Contract Number is a required field' after API change, skipping because no clue how to fix, might need different creds"
    opts = {:customer_number => "0000000000", :service => "DOM.XP"}
    assert_raises(ResponseError) do
      @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)
    end
  end
end
