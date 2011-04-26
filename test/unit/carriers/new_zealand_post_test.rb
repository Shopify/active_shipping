require "test_helper"

class NewZealandPostTest < Test::Unit::TestCase

  def setup
    @carrier  = NewZealandPost.new(:key => "4d9dc0f0-dda0-012e-066f-000c29b44ac0")
    @packages  = TestFixtures.packages
    @locations = TestFixtures.locations
    @wellington = @locations[:wellington]
    @auckland = @locations[:auckland]
    @ottawa = @locations[:ottawa]
  end

  def test_domestic_book_request
    url = "http://api.nzpost.co.nz/ratefinder/domestic?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&carrier=all&format=json&height=20&length=190&postcode_dest=1010&postcode_src=6011&thickness=140&weight=0.25"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_book") ])
    @carrier.find_rates(@wellington, @auckland, @packages[:book])
  end

  def test_domestic_poster_request
    url = "http://api.nzpost.co.nz/ratefinder/domestic?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&carrier=all&diameter=100&format=json&length=930&postcode_dest=1010&postcode_src=6011&weight=0.1"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_poster") ])
    @carrier.find_rates(@wellington, @auckland, @packages[:poster])
  end

  def test_domestic_combined_request
    urls = [
      "http://api.nzpost.co.nz/ratefinder/domestic?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&carrier=all&format=json&height=20&length=190&postcode_dest=1010&postcode_src=6011&thickness=140&weight=0.25",
      "http://api.nzpost.co.nz/ratefinder/domestic?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&carrier=all&format=json&height=25.4&length=25.4&postcode_dest=1010&postcode_src=6011&thickness=25.4&weight=0.226796185"
    ]
    @carrier.expects(:commit).with(urls).returns([ json_fixture("newzealandpost/domestic_book"), json_fixture("newzealandpost/domestic_small_half_pound") ])
    @carrier.find_rates(@wellington, @auckland, @packages.values_at(:book, :small_half_pound))
  end

  def test_domestic_book_response
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_book") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:book])
    assert_equal 13, response.rates.size
    assert_equal [ 300, 360, 400, 420, 450, 450, 500, 500, 550, 655, 715, 880, 890 ], response.rates.map(&:price)
  end

  def test_domestic_poster_response
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_poster") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:poster])
    assert_equal 1, response.rates.size
    assert_equal [ 750 ], response.rates.map(&:price)
  end

  def test_domestic_combined_response_parsing
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_book"), json_fixture("newzealandpost/domestic_small_half_pound") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages.values_at(:book, :small_half_pound))
    assert_equal 8, response.rates.size
    assert_equal [ 800, 840, 900, 900, 1000, 1100, 1430, 1780 ], response.rates.map(&:price)
    assert_equal [ "PIKFC5", "PCB3C5", "PIFFC5", "PIKBC5", "PIFBC5", "PICBC5", "NZPRBA5", "NZSRBA5" ], response.rates.map(&:service_code)
    names = [
      "ParcelPost C5 Flat Bag",
      "ParcelPost Tracked C5 Postage Only - Tracked",
      "ParcelPost Fast C5 Flat Bag",
      "ParcelPost C5 Bubble Bag",
      "ParcelPost Fast C5 Bubble Bag",
      "ParcelPost Tracked C5 Bubble Bag - Tracked",
      "Courier C5 Ready To Go Courier Bubble Bag",
      "Courier C5 Ready To Go Courier Bubble Bag S/R"
    ]
    assert_equal names, response.rates.map(&:service_name)
  end

  def test_domestic_shipping_container_response_error
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/domestic_error") ])
    error = @carrier.find_rates(@wellington, @auckland, @packages[:shipping_container]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert_equal "Weight can only be between 0 and 25kg", error.message
    assert_equal [ json_fixture("newzealandpost/domestic_error") ], error.response.raw_responses
    response_params = { "responses" => [ JSON.parse(json_fixture("newzealandpost/domestic_error")) ] }
    assert_equal response_params, error.response.params
  end

  def test_domestic_blank_package_response
    url = "http://api.nzpost.co.nz/ratefinder/domestic?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&carrier=all&format=json&height=0&length=0&postcode_dest=1010&postcode_src=6011&thickness=0&weight=0.0"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_default") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:just_zero_grams])
    assert_equal [ 240, 300, 400, 420, 450, 450, 450, 500, 550, 589, 715, 830, 890 ], response.rates.map(&:price)
  end

  def test_domestic_book_response_params
    url = "http://api.nzpost.co.nz/ratefinder/domestic?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&carrier=all&format=json&height=20&length=190&postcode_dest=1010&postcode_src=6011&thickness=140&weight=0.25"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/domestic_book") ])
    response = @carrier.find_rates(@wellington, @auckland, @packages[:book])
    assert_equal [ url ], response.request
    assert_equal [ json_fixture("newzealandpost/domestic_book") ], response.raw_responses
    assert_equal [ JSON.parse(json_fixture("newzealandpost/domestic_book")) ], response.params["responses"]
  end

  def test_international_book_request
    url = "http://api.nzpost.co.nz/ratefinder/international?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&country_code=CA&format=json&height=20&length=190&thickness=140&value=0&weight=0.25"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_book") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:book])
  end

  def test_international_wii_request
    url = "http://api.nzpost.co.nz/ratefinder/international?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&country_code=CA&format=json&height=114.3&length=381.0&thickness=254.0&value=269&weight=3.401942775"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_new_zealand_wii") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:new_zealand_wii])
  end

  def test_international_uk_wii_request
    url = "http://api.nzpost.co.nz/ratefinder/international?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&country_code=CA&format=json&height=114.3&length=381.0&thickness=254.0&value=0&weight=3.401942775"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_wii") ])
    @carrier.find_rates(@wellington, @ottawa, @packages[:wii])
  end

  def test_international_book_response_params
    url = "http://api.nzpost.co.nz/ratefinder/international?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&country_code=CA&format=json&height=20&length=190&thickness=140&value=0&weight=0.25"
    @carrier.expects(:commit).with([ url ]).returns([ json_fixture("newzealandpost/international_book") ])
    response = @carrier.find_rates(@wellington, @ottawa, @packages[:book])
    assert_equal [ url ], response.request
    assert_equal [ json_fixture("newzealandpost/international_book") ], response.raw_responses
    assert_equal [ JSON.parse(json_fixture("newzealandpost/international_book")) ], response.params["responses"]
  end

  def test_international_combined_request
    urls = [
      "http://api.nzpost.co.nz/ratefinder/international?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&country_code=CA&format=json&height=20&length=190&thickness=140&value=0&weight=0.25",
      "http://api.nzpost.co.nz/ratefinder/international?api_key=4d9dc0f0-dda0-012e-066f-000c29b44ac0&country_code=CA&format=json&height=25.4&length=25.4&thickness=25.4&value=0&weight=0.226796185"
    ]
    @carrier.expects(:commit).with(urls).returns([ json_fixture("newzealandpost/international_book"), json_fixture("newzealandpost/international_wii") ])
    @carrier.find_rates(@wellington, @ottawa, @packages.values_at(:book, :small_half_pound))
  end

  def test_international_combined_response_parsing
    @carrier.expects(:commit).returns([ json_fixture("newzealandpost/international_book"), json_fixture("newzealandpost/international_small_half_pound") ])
    response = @carrier.find_rates(@wellington, @ottawa, @packages.values_at(:book, :small_half_pound))
    assert_equal 4, response.rates.size
    assert_equal [ 13050, 8500, 2460, 2214 ], response.rates.map(&:price)
    assert_equal [ "ICPNC500", "IEZPC500", "IACNC500", "IECNC500" ], response.rates.map(&:service_code)
    names = [
      "International Express Courier Int Express Pcl Zone C 500gm",
      "International Economy Courier Int Econ Cour Pcl Zn C 500gm",
      "International Air Zone C AirPost Cust Pcl 500gm",
      "International Economy Zone C EconomyPost Pcl 500gm"
    ]
    assert_equal names, response.rates.map(&:service_name)
  end

  def test_international_empty_json_response_error
    @carrier.expects(:commit).returns([ "" ])
    error = @carrier.find_rates(@wellington, @ottawa, @packages[:book]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert_equal "A JSON text must at least contain two octets!", error.message
    assert_equal [ "" ], error.response.raw_responses
    response_params = { "responses" => [] }
    assert_equal response_params, error.response.params
  end

  def test_international_invalid_json_response_error
    @carrier.expects(:commit).returns([ "<>" ])
    error = @carrier.find_rates(@wellington, @ottawa, @packages[:book]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert error.message.include?("unexpected token")
    assert_equal [ "<>" ], error.response.raw_responses
    response_params = { "responses" => [] }
    assert_equal response_params, error.response.params
  end

  def test_international_invalid_origin_country_response
    error = @carrier.find_rates(@ottawa, @wellington, @packages[:book]) rescue $!
    assert_equal ActiveMerchant::Shipping::ResponseError, error.class
    assert_equal "New Zealand Post packages must originate in New Zealand", error.message
    assert_equal [], error.response.raw_responses
    assert_equal Array, error.response.request.class
    assert_equal 1, error.response.request.size
    response_params = { "responses" => [] }
    assert_equal response_params, error.response.params
  end

end
