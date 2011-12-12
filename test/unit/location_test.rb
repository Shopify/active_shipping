require 'test_helper'

class LocationTest < Test::Unit::TestCase
  include ActiveMerchant::Shipping
  
  def setup
    @locations = TestFixtures.locations.dup
  end

  def test_countries
    assert_instance_of ActiveMerchant::Country, @locations[:ottawa].country
    assert_equal 'CA', @locations[:ottawa].country_code(:alpha2)
  end
  
  def test_location_from_strange_hash
    hash = {  :country => 'CA',
              :zip => '90210',
              :territory_code => 'QC', 
              :town => 'Perth',
              :address => '66 Gregory Ave.', 
              :phone => '515-555-1212',
              :fax_number => 'none to speak of',
              :address_type => :commercial
            }
    location = Location.from(hash)
    
    assert_equal hash[:country], location.country_code(:alpha2)
    assert_equal hash[:zip], location.zip
    assert_equal hash[:territory_code], location.province
    assert_equal hash[:town], location.city
    assert_equal hash[:address], location.address1
    assert_equal hash[:phone], location.phone
    assert_equal hash[:fax_number], location.fax
    assert_equal hash[:address_type].to_s, location.address_type
  end
  
  def to_s
    expected = "110 Laurier Avenue West\nOttawa, ON, K1P 1J1\nCanada"
    assert_equal expected, @locations[:ottawa].to_s
  end
  
  def test_inspect
    expected = "110 Laurier Avenue West\nOttawa, ON, K1P 1J1\nCanada\nPhone: 1-613-580-2400\nFax: 1-613-580-2495"
    assert_equal expected, @locations[:ottawa].inspect
  end
  
  def test_includes_name
    location = Location.from(:name => "Bob Bobsen")
    assert_equal "Bob Bobsen", location.name
  end
  
  def test_name_is_nil_if_not_provided
    location = Location.from({})
    assert_nil location.name
  end

  def test_location_with_company_name
    location = Location.from(:company => "Mine")
    assert_equal "Mine", location.company_name

    location = Location.from(:company_name => "Mine")
    assert_equal "Mine", location.company_name
  end

  def test_set_address_type
    location = @locations[:ottawa]
    assert !location.commercial?

    location.address_type = :commercial
    assert location.commercial?
  end

  def test_set_address_type_invalid
    location = @locations[:ottawa]

    assert_raises ArgumentError do
      location.address_type = :new_address_type
    end

    assert_not_equal "new_address_type", location.address_type
  end

  def test_to_hash_attributes
    assert_equal %w(address1 address2 address3 address_type city company_name country fax name phone postal_code province), @locations[:ottawa].to_hash.stringify_keys.keys.sort
  end

  def test_to_json
    location_json = @locations[:ottawa].to_json
    assert_equal @locations[:ottawa].to_hash, ActiveSupport::JSON.decode(location_json).symbolize_keys
  end

  def test_default_to_xml
    location_xml = @locations[:ottawa].to_xml
    assert_equal @locations[:ottawa].to_hash, Hash.from_xml(location_xml)["location"].symbolize_keys
  end

  def test_custom_root_to_xml
    location_xml = @locations[:ottawa].to_xml(:root => "destination")
    assert_equal @locations[:ottawa].to_hash, Hash.from_xml(location_xml)["destination"].symbolize_keys
  end

  def test_zip_plus_4_with_no_dash
    zip = "33333"
    plus_4 = "1234"
    zip_plus_4 = "#{zip}-#{plus_4}"
    location = Location.from(:zip => zip+plus_4)
    assert_equal zip_plus_4, location.zip_plus_4
  end

  def test_zip_plus_4_with_dash
    zip = "33333"
    plus_4 = "1234"
    zip_plus_4 = "#{zip}-#{plus_4}"
    location = Location.from(:zip => zip_plus_4)
    assert_equal zip_plus_4, location.zip_plus_4
  end
end
