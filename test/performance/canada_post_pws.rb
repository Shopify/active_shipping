require 'test_helper'

class CanadaPostPWSTest < Test::Unit::TestCase
  
  def setup

    @login = fixtures(:canada_post_pws)

    @cp = CanadaPostPWS.new(login.merge(:endpoint => "https://ct.soa-gw.canadapost.ca/"))
    # @cp.logger = Logger.new(STDOUT)

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

    @pkg1 = Package.new(1000, nil, :value => 10.00)

    @line_item1 = TestFixtures.line_items1

  end

  def test_generate_and_retrieve_shipping_label
    time = Benchmark.measure do
      10.times do 
        opts = {:customer_number => @login[:customer_number], :service => "DOM.XP"}
        response = @cp.create_shipment(@home_params, @dom_params, @pkg1, @line_item1, opts)
        response = @cp.retrieve_shipping_label(response)
      end
    end
    puts time
  end

end