require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  include ActiveShipping::Test::Fixtures

  setup do
    @location = location_fixtures[:ottawa]
    @address2 = 'Apt 613'
    @address3 = 'Victory Lane'
    @attributes_hash = {
      country: 'CA',
      zip: '90210',
      territory_code: 'QC',
      town: 'Perth',
      address: '66 Gregory Ave.',
      phone: '515-555-1212',
      fax_number: 'none to speak of',
      email: 'bob.bobsen@gmail.com',
      address_type: :commercial,
      name: "Bob Bobsen",
    }
  end

  test "#initialize sets a country object" do
    assert_instance_of ActiveUtils::Country, @location.country
    assert_equal 'CA', @location.country_code(:alpha2)
  end

  test ".from sets up the location from a hash" do
    location = Location.from(@attributes_hash)

    assert_equal @attributes_hash[:country], location.country_code(:alpha2)
    assert_equal @attributes_hash[:zip], location.zip
    assert_equal @attributes_hash[:territory_code], location.province
    assert_equal @attributes_hash[:town], location.city
    assert_equal @attributes_hash[:address], location.address1
    assert_equal @attributes_hash[:phone], location.phone
    assert_equal @attributes_hash[:fax_number], location.fax
    assert_equal @attributes_hash[:email], location.email
    assert_equal @attributes_hash[:address_type].to_s, location.address_type
    assert_equal @attributes_hash[:name], location.name
  end

  test ".from sets from an object with properties" do
    object = Class.new do
      def initialize(hash)
        @hash = hash
      end
      def method_missing(method)
        @hash[method]
      end
      def respond_to?(method)
        return false if method == :[]
        true
      end
    end.new(@attributes_hash)

    location = Location.from(object)

    assert_equal @attributes_hash[:country], location.country_code(:alpha2)
    assert_equal @attributes_hash[:zip], location.zip
    assert_equal @attributes_hash[:territory_code], location.province
    assert_equal @attributes_hash[:town], location.city
    assert_equal @attributes_hash[:address], location.address1
    assert_equal @attributes_hash[:phone], location.phone
    assert_equal @attributes_hash[:fax_number], location.fax
    assert_equal @attributes_hash[:email], location.email
    assert_equal @attributes_hash[:address_type].to_s, location.address_type
    assert_equal @attributes_hash[:name], location.name
  end

  test ".from adheres to propery order even if hash access is available" do
    object = Class.new do
      def [](index)
        { province: "California" }[index]
      end

      def province_code
        "CA"
      end
    end.new
    assert_equal "CA", Location.from(object).province
  end

  test ".from sets the name to nil if it is not provided" do
    location = Location.from({})
    assert_nil location.name
  end

  test ".from sets company and company_name from company" do
    location = Location.from(company: "Mine")

    assert_equal "Mine", location.company
    assert_equal "Mine", location.company_name
  end

  test ".from sets company and company_name from company_name" do
    location = Location.from(company_name: "Mine")

    assert_equal "Mine", location.company
    assert_equal "Mine", location.company_name
  end

  test ".from prioritizes company" do
    location = Location.from(company_name: "from company_name", company: "from company")

    assert_equal "from company", location.company
    assert_equal "from company", location.company_name
  end

  test "#prettyprint outputs a readable string" do
    expected = "110 Laurier Avenue West\nOttawa, ON, K1P 1J1\nCanada"
    assert_equal expected, @location.prettyprint
  end

  test "#to_s outputs a readable string without newlines" do
    expected = "110 Laurier Avenue West Ottawa, ON, K1P 1J1 Canada"
    assert_equal expected, @location.to_s
  end

  test "#inspect returns a readable string" do
    expected = "110 Laurier Avenue West\nOttawa, ON, K1P 1J1\nCanada\nPhone: 1-613-580-2400\nFax: 1-613-580-2495\nEmail: bob.bobsen@gmail.com"
    assert_equal expected, @location.inspect
  end

  test "#address_type= assigns a type of address as commercial" do
    refute @location.commercial?

    @location.address_type = :commercial
    assert @location.commercial?
    refute @location.residential?
    assert_equal "commercial", @location.address_type
  end

  test "#address_type= assigns a type of address as residential" do
    refute @location.residential?

    @location.address_type = :residential
    assert @location.residential?
    refute @location.commercial?
    assert_equal "residential", @location.address_type
  end

  test "#address_type= raises on an invalid assignment" do
    assert_raises(ArgumentError) do
      @location.address_type = :new_address_type
    end

    assert_nil @location.address_type
  end

  test "#address_type= cannot blank out the value as nil" do
    @location.address_type = :residential
    assert @location.residential?

    @location.address_type = nil
    assert @location.residential?
    assert_equal "residential", @location.address_type
  end

  test "#address_type= cannot blank out the value as empty string" do
    @location.address_type = :residential
    assert @location.residential?

    @location.address_type = ""
    assert @location.residential?
    assert_equal "residential", @location.address_type
  end

  test "#to_hash has the expected attributes" do
    expected = %w(address1 address2 address3 address_type city company_name country email fax name phone postal_code province)

    assert_equal expected, @location.to_hash.stringify_keys.keys.sort
  end

  test "#to_json returns the JSON values" do
    expected = JSON.parse(@location.to_json).symbolize_keys

    assert_equal @location.to_hash, expected
  end

  test "#zip_plus_4 nil without the extra four" do
    zip = "12345"
    location = Location.from(zip: zip)

    assert_nil location.zip_plus_4
    assert_equal zip, location.zip
  end

  test "#zip_plus_4 parses without the dash" do
    zip = "12345-9999"
    zip_without_dash = "123459999"
    location = Location.from(zip: zip_without_dash)

    assert_equal zip, location.zip_plus_4
    assert_equal zip_without_dash, location.zip
  end

  test "#zip_plus_4 parses with the dash" do
    zip = "12345-9999"
    location = Location.from(zip: zip)

    assert_equal zip, location.zip_plus_4
    assert_equal zip, location.zip
  end

  test "#address2_and_3 shows just address2" do
    location = Location.from(address2: @address2)
    assert_equal 'Apt 613', location.address2_and_3
  end

  test "#address2_and_3 shows just address3" do
    location = Location.from(address3: @address3)
    assert_equal @address3, location.address2_and_3
  end

  test "#address2_and_3 shows both address2 and address3" do
    location = Location.from(address2: @address2, address3: @address3)
    assert_equal "#{@address2}, #{@address3}", location.address2_and_3
  end

  test "#address2_and_3 shows an empty string when address2 and address3 are both blank" do
    assert_nil @location.address2
    assert_nil @location.address3
    assert_equal "", @location.address2_and_3
  end

  test "#== compares locations by attributes" do
    another_location = Location.from(@location.to_hash)

    assert_equal @location, another_location
    refute_equal @location, Location.new({})
  end
end
