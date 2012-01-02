require 'rubygems'
require 'active_shipping'
include ActiveMerchant::Shipping

XmlNode

# Package up a poster and a Wii for your nephew.
packages = [
  Package.new(  100,                        # 100 grams
                [93,10],                    # 93 cm long, 10 cm diameterf
                :cylinder => true),         # cylinders have different volume calculations

  Package.new(  (7.5 * 16),                 # 7.5 lbs, times 16 oz/lb.
                [15, 10, 4.5],              # 15x10x4.5 inches
                :units => :imperial)        # not grams, not centimetres
]


# You live in Beverly Hills, he lives in Ottawa
dest = Location.new(:country => 'US', :state => 'CA', :city => 'Beverly Hills', :zip => '90210')
src  = Location.new(:country => 'CA', :province => 'ON', :city => 'Ottawa', :postal_code => 'K1P 1J1')
                          
# Find out how much it'll be.
cp = CanadaPostPWS.new(:api_key => 'c70da5ed5a0d2c32', :secret => 'b438ff7d9e581cd0d2edbe', :language => 'fr')
response = cp.find_tracking_info('1371134583769923', {})

response.shipment_events.reverse.map {|e| puts "#{e.name}: #{e.time.to_s(:short)} #{e.location} #{e.message}"}

p response.tracking_number
p response.service_name
p response.expected_date
p response.changed_date
p response.change_reason


