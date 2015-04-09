require 'bundler/setup'

require 'minitest/autorun'
require 'mocha/mini_test'
require 'timecop'
require 'business_time'

require 'active_shipping'
require 'logger'
require 'erb'

# This makes sure that Minitest::Test exists when an older version of Minitest
# (i.e. 4.x) is required by ActiveSupport.
unless defined?(Minitest::Test)
  Minitest::Test = MiniTest::Unit::TestCase
end


class Minitest::Test
  include ActiveShipping
end

module ActiveShipping::Test
  module Credentials
    class NoCredentialsFound < StandardError
      def initialize(key)
        super("No credentials were found for '#{key}'")
      end
    end

    LOCAL_CREDENTIALS = ENV['HOME'] + '/.active_shipping/credentials.yml'
    DEFAULT_CREDENTIALS = File.dirname(__FILE__) + '/credentials.yml'

    def credentials(key)
      data = all_credentials[key]
      if data.nil? || data.all? { |k,v| v.nil? || v.to_s.empty? }
        raise NoCredentialsFound.new(key)
      end
      data.symbolize_keys
    end

    private

    def all_credentials
      @@all_credentials ||= begin
        [DEFAULT_CREDENTIALS, LOCAL_CREDENTIALS].inject({}) do |credentials, file_name|
          if File.exist?(file_name)
            yaml_data = YAML.load(ERB.new(File.read(file_name)).result(binding)).symbolize_keys
            credentials.merge!(yaml_data)
          end
          credentials
        end
      end
    end
  end

  module Fixtures
    include ActiveShipping

    def xml_fixture(path) # where path is like 'usps/beverly_hills_to_ottawa_response'
      File.read(File.join(File.dirname(__FILE__), 'fixtures', 'xml', "#{path}.xml"))
    end

    def json_fixture(path) # where path is like 'usps/beverly_hills_to_ottawa_response'
      File.read(File.join(File.dirname(__FILE__), 'fixtures', 'json', "#{path}.json"))
    end

    def file_fixture(filename)
      File.read(File.join(File.dirname(__FILE__), 'fixtures', 'files', filename), mode: "rb")
    end

    def package_fixtures
      @package_fixtures ||= {
        :just_ounces => Package.new(16, nil, :units => :imperial),
        :just_grams => Package.new(1000, nil),
        :just_zero_grams => Package.new(0, nil),
        :all_imperial => Package.new(16, [1, 8, 12], :units => :imperial),
        :all_metric => Package.new(1000, [2, 20, 40]),
        :book => Package.new(250, [14, 19, 2]),
        :wii => Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial, :value => 269.99, :currency => 'GBP'),
        :american_wii => Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial, :value => 269.99, :currency => 'USD'),
        :new_zealand_wii => Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial, :value => 269.99, :currency => 'NZD'),
        :worthless_wii => Package.new((7.5 * 16), [15, 10, 4.5], :units => :imperial, :value => 0.0, :currency => 'USD'),
        :poster => Package.new(100, [93, 10], :cylinder => true),
        :small_half_pound => Package.new(8, [1, 1, 1], :units => :imperial),
        :big_half_pound => Package.new((16 * 50), [24, 24, 36], :units => :imperial),
        :chocolate_stuff => Package.new(80, [2, 6, 12], :units => :imperial),
        :declared_value => Package.new(80, [2, 6, 12], :units => :imperial, :currency => 'USD', :value => 999.99),
        :tshirts => Package.new(10 * 16, nil, :units => :imperial),
        :shipping_container => Package.new(2200000, [2440, 2600, 6058], :description => '20 ft Standard Container', :units => :metric),
        :largest_gold_bar => Package.new(250000, [45.5, 22.5, 17], :value => 15300000),
        :books => Package.new(64, [4, 8, 6], :units => :imperial, :value => 15300000, :description => 'Books')
      }
    end

    def location_fixtures
      @location_fixtures ||= {
        :bare_ottawa => Location.new(:country => 'CA', :postal_code => 'K1P 1J1'),
        :bare_beverly_hills => Location.new(:country => 'US', :zip => '90210'),
        :ottawa => Location.new( :country => 'CA',
                                 :province => 'ON',
                                 :city => 'Ottawa',
                                 :address1 => '110 Laurier Avenue West',
                                 :postal_code => 'K1P 1J1',
                                 :phone => '1-613-580-2400',
                                 :fax => '1-613-580-2495'),
        :ottawa_with_name => Location.new( :country => 'CA',
                                           :province => 'ON',
                                           :city => 'Ottawa',
                                           :name => 'Paul Ottawa',
                                           :address1 => '110 Laurier Avenue West',
                                           :postal_code => 'K1P 1J1',
                                           :phone => '1-613-580-2400',
                                           :fax => '1-613-580-2495'),
        :beverly_hills => Location.new(
                                      :country => 'US',
                                      :state => 'CA',
                                      :city => 'Beverly Hills',
                                      :address1 => '455 N. Rexford Dr.',
                                      :address2 => '3rd Floor',
                                      :zip => '90210',
                                      :phone => '1-310-285-1013',
                                      :fax => '1-310-275-8159'),
        :real_home_as_commercial => Location.new(
                                      :country => 'US',
                                      :city => 'Tampa',
                                      :state => 'FL',
                                      :company => 'Tampa Company',
                                      :address1 => '7926 Woodvale Circle',
                                      :zip => '33615',
                                      :address_type => 'commercial'), # means that UPS will default to commercial if it doesn't know
        :fake_home_as_commercial => Location.new(
                                      :country => 'US',
                                      :state => 'FL',
                                      :address1 => '123 fake st.',
                                      :zip => '33615',
                                      :address_type => 'commercial'),
        :real_google_as_commercial => Location.new(
                                      :country => 'US',
                                      :city => 'Mountain View',
                                      :state => 'CA',
                                      :address1 => '1600 Amphitheatre Parkway',
                                      :zip => '94043',
                                      :address_type => 'commercial'),
        :real_google_as_residential => Location.new(
                                      :country => 'US',
                                      :city => 'Mountain View',
                                      :state => 'CA',
                                      :address1 => '1600 Amphitheatre Parkway',
                                      :zip => '94043',
                                      :address_type => 'residential'), # means that will default to residential if it doesn't know
        :fake_google_as_commercial => Location.new(
                                      :country => 'US',
                                      :city => 'Mountain View',
                                      :state => 'CA',
                                      :address1 => '123 bogusland dr.',
                                      :zip => '94043',
                                      :address_type => 'commercial'),
        :fake_google_as_residential => Location.new(
                                      :country => 'US',
                                      :city => 'Mountain View',
                                      :state => 'CA',
                                      :address1 => '123 bogusland dr.',
                                      :zip => '94043',
                                      :address_type => 'residential'), # means that will default to residential if it doesn't know
        :fake_home_as_residential => Location.new(
                                      :country => 'US',
                                      :state => 'FL',
                                      :address1 => '123 fake st.',
                                      :zip => '33615',
                                      :address_type => 'residential'),
        :real_home_as_residential => Location.new(
                                      :country => 'US',
                                      :city => 'Tampa',
                                      :state => 'FL',
                                      :address1 => '7926 Woodvale Circle',
                                      :zip => '33615',
                                      :address_type => 'residential'),
        :london => Location.new(
                                      :country => 'GB',
                                      :city => 'London',
                                      :address1 => '170 Westminster Bridge Rd.',
                                      :zip => 'SE1 7RW'),
        :new_york => Location.new(
                                      :country => 'US',
                                      :city => 'New York',
                                      :state => 'NY',
                                      :address1 => '780 3rd Avenue',
                                      :address2 => 'Suite  2601',
                                      :zip => '10017'),
        :new_york_with_name => Location.new(
                                      :name => "Bob Bobsen",
                                      :country => 'US',
                                      :city => 'New York',
                                      :state => 'NY',
                                      :address1 => '780 3rd Avenue',
                                      :address2 => 'Suite  2601',
                                      :zip => '10017',
                                      :phone => '123-123-1234'),
        :wellington => Location.new(
                                      :country => 'NZ',
                                      :city => 'Wellington',
                                      :address1 => '85 Victoria St',
                                      :address2 => 'Te Aro',
                                      :postal_code => '6011'),
        :auckland => Location.new(
                                      :country => 'NZ',
                                      :city => 'Auckland',
                                      :address1 => '192 Victoria St West',
                                      :postal_code => '1010'),
        :puerto_rico => Location.new(
                                      :country => 'PR',
                                      :city => 'Barceloneta',
                                      :address1 => '1 Nueva St',
                                      :postal_code => '00617'),
        :annapolis => Location.new(
                                      :name => 'Big Red',
                                      :country => 'US',
                                      :city => 'Annapolis',
                                      :address1 => '1 Park Place',
                                      :address2 => '#7',
                                      :postal_code => '21401'),
        :netherlands => Location.new( :country => 'NL',
                                      :city => 'Groningen',
                                      :address1 => 'Aquamarijnstraat 349',
                                      :postal_code => '9743 PJ',
                                      :state => 'Groningen')
      }
    end

    def line_item_fixture
      @line_item_fixture ||= [
        PackageItem.new("IPod Nano - 8gb - green", 200, 199.00, 2, :sku => "IPOD2008GREEN", :hs_code => "1234.12.12.12"),
        PackageItem.new("IPod Nano - 8gb - black", 200, 199.00, 1, :sku => "IPOD2008GREEN", :hs_code => "1234.12.12.12")
      ]
    end
  end
end
