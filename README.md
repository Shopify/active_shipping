# ActiveShipping [![Build status](https://travis-ci.org/Shopify/active_shipping.svg?branch=master)](https://travis-ci.org/Shopify/active_shipping)

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API.

- Finding shipping rates
- Registering shipments
- Tracking shipments
- Purchasing shipping labels

Active Shipping is currently being used and improved in a production environment for [Shopify][]. Development is being done by the Shopify integrations team (<integrations-team@shopify.com>). Discussion is welcome in the [Active Merchant Google Group][discuss].

[Shopify]:http://www.shopify.com
[discuss]:http://groups.google.com/group/activemerchant

## Supported Shipping Carriers

* [UPS](http://www.ups.com)
* [USPS](http://www.usps.com)
* [USPS Returns](http://returns.usps.com)
* [FedEx](http://www.fedex.com)
* [Canada Post](http://www.canadapost.ca)
* [New Zealand Post](http://www.nzpost.co.nz)
* [Shipwire](http://www.shipwire.com)
* [Stamps](http://www.stamps.com)
* [Kunaki](http://www.kunaki.com)
* [Australia Post](http://auspost.com.au/)

## Installation

```ruby
gem install active_shipping
```

...or add it to your project's [Gemfile](http://bundler.io/).

## Sample Usage

### Compare rates from different carriers

```ruby
require 'active_shipping'

# Package up a poster and a Wii for your nephew.
packages = [
  ActiveShipping::Package.new(100,               # 100 grams
                              [93,10],           # 93 cm long, 10 cm diameter
                              cylinder: true),   # cylinders have different volume calculations

  ActiveShipping::Package.new(7.5 * 16,          # 7.5 lbs, times 16 oz/lb.
                              [15, 10, 4.5],     # 15x10x4.5 inches
                              units: :imperial)  # not grams, not centimetres
 ]

 # You live in Beverly Hills, he lives in Ottawa
 origin = ActiveShipping::Location.new(country: 'US',
                                       state: 'CA',
                                       city: 'Beverly Hills',
                                       zip: '90210')

 destination = ActiveShipping::Location.new(country: 'CA',
                                            province: 'ON',
                                            city: 'Ottawa',
                                            postal_code: 'K1P 1J1')

 # Find out how much it'll be.
 ups = ActiveShipping::UPS.new(login: 'auntjudy', password: 'secret', key: 'xml-access-key')
 response = ups.find_rates(origin, destination, packages)

 ups_rates = response.rates.sort_by(&:price).collect {|rate| [rate.service_name, rate.price]}
 # => [["UPS Standard", 3936],
 #     ["UPS Worldwide Expedited", 8682],
 #     ["UPS Saver", 9348],
 #     ["UPS Express", 9702],
 #     ["UPS Worldwide Express Plus", 14502]]

 # Check out USPS for comparison...
 usps = ActiveShipping::USPS.new(login: 'developer-key')
 response = usps.find_rates(origin, destination, packages)

 usps_rates = response.rates.sort_by(&:price).collect {|rate| [rate.service_name, rate.price]}
 # => [["USPS Priority Mail International", 4110],
 #     ["USPS Express Mail International (EMS)", 5750],
 #     ["USPS Global Express Guaranteed Non-Document Non-Rectangular", 9400],
 #     ["USPS GXG Envelopes", 9400],
 #     ["USPS Global Express Guaranteed Non-Document Rectangular", 9400],
 #     ["USPS Global Express Guaranteed", 9400]]
```

### Track a FedEx package

```ruby
fedex = ActiveShipping::FedEx.new(login: '999999999', password: '7777777', key: '1BXXXXXXXXXxrcB', account: '51XXXXX20')
tracking_info = fedex.find_tracking_info('tracking-number', carrier_code: 'fedex_ground') # Ground package

tracking_info.shipment_events.each do |event|
  puts "#{event.name} at #{event.location.city}, #{event.location.state} on #{event.time}. #{event.message}"
end
# => Package information transmitted to FedEx at NASHVILLE LOCAL, TN on Thu Oct 23 00:00:00 UTC 2008.
# Picked up by FedEx at NASHVILLE LOCAL, TN on Thu Oct 23 17:30:00 UTC 2008.
# Scanned at FedEx sort facility at NASHVILLE, TN on Thu Oct 23 18:50:00 UTC 2008.
# Departed FedEx sort facility at NASHVILLE, TN on Thu Oct 23 22:33:00 UTC 2008.
# Arrived at FedEx sort facility at KNOXVILLE, TN on Fri Oct 24 02:45:00 UTC 2008.
# Scanned at FedEx sort facility at KNOXVILLE, TN on Fri Oct 24 05:56:00 UTC 2008.
# Delivered at Knoxville, TN on Fri Oct 24 16:45:00 UTC 2008. Signed for by: T.BAKER
```

#### FedEx connection notes

The :login key passed to ```ActiveShipping::FedEx.new()``` is really the FedEx meter number, not the FedEx login.

When developing with test credentials, be sure to pass ```test: true``` to ```ActiveShipping::FedEx.new()``` .

## Running the tests

After installing dependencies with `bundle install`, you can run the unit tests with `rake test:unit` and the remote tests with `rake test:remote`. The unit tests mock out requests and responses so that everything runs locally, while the remote tests actually hit the carrier servers. For the remote tests, you'll need valid test credentials for any carriers' tests you want to run. The credentials should go in ~/.active_shipping/credentials.yml, and the format of that file can be seen in the included [credentials.yml](https://github.com/Shopify/active_shipping/blob/master/test/credentials.yml). For some carriers, we have public credentials you can use for testing: see `.travis.yml`.

## Development

Yes, please! Take a look at the tests and the implementation of the Carrier class to see how the basics work. At some point soon there will be a carrier template generator along the lines of the gateway generator included in Active Merchant, but carrier.rb outlines most of what's necessary. The other main classes that would be good to familiarize yourself with are Location, Package, and Response.

For the features you add, you should have both unit tests and remote tests. It's probably best to start with the remote tests, and then log those requests and responses and use them as the mocks for the unit tests. You can see how this works with the USPS tests right now:

https://github.com/Shopify/active_shipping/blob/master/test/remote/usps_test.rb
https://github.com/Shopify/active_shipping/blob/master/test/unit/carriers/usps_test.rb
https://github.com/Shopify/active_shipping/tree/master/test/fixtures/xml/usps

To log requests and responses, just set the `logger` on your carrier class to some kind of `Logger` object:

```ruby
ActiveShipping::USPS.logger = Logger.new($stdout)
```

(This logging functionality is provided by the [`PostsData` module](https://github.com/Shopify/active_utils/blob/master/lib/active_utils/posts_data.rb) in the `active_utils` dependency.)

To debug API requests and your code you can run `rake console` to start a Pry session with `ActiveShipping` included
and instances of the various carriers set up with your test credentials.
Look at the file `test/console.rb` to see the other goodies it provides.

After you've pushed your well-tested changes to your github fork, make a pull request and we'll take it from there! For more information, see CONTRIBUTING.md.

## Legal Mumbo Jumbo

Unless otherwise noted in specific files, all code in the ActiveShipping project is under the copyright and license described in the included MIT-LICENSE file.
