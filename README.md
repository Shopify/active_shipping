# ActiveShipping [![Build status](https://travis-ci.org/Shopify/active_shipping.svg?branch=master)](https://travis-ci.org/Shopify/active_shipping)

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API:

- Finding shipping rates
- Registering shipments
- Tracking shipments
- Purchasing shipping labels

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


## Versions
Note: `2.x` contains breaking changes, please see the [changelog](https://github.com/Shopify/active_shipping/blob/master/CHANGELOG.md). Shopify will not be actively contibuting to the 2.0 version of this gem and is looking for maintainers.
We have released `1.9` and will only backport small fixes to this version, on branch `1-9-stable`, and they should be on `master` first.

## Installation

Using bundler, add to the `Gemfile`:

```ruby
gem 'active_shipping'
```

Or stand alone:

```
$ gem install active_shipping
```


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

Dimensions for packages are in `Height x Width x Length` order.

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

## Carrier specific notes

### FedEx connection

The `:login` key passed to `ActiveShipping::FedEx.new()` is really the FedEx meter number, not the FedEx login.

When developing with test credentials, be sure to pass `test: true` to `ActiveShipping::FedEx.new()`.


## Tests

You can run the unit tests with:

```
bundle exec rake test:unit
```

and the remote tests with:

```
bundle exec rake test:remote
```

The unit tests mock out requests and responses so that everything runs locally, while the remote tests actually hit the carrier servers. For the remote tests, you'll need valid test credentials for any carriers' tests you want to run. The credentials should go in [`~/.active_shipping/credentials.yml`](https://github.com/Shopify/active_shipping/blob/master/test/credentials.yml). For some carriers, we have public credentials you can use for testing in `.travis.yml`. Remote tests missing credentials will be skipped.


## Contributing

See [CONTRIBUTING.md](https://github.com/Shopify/active_shipping/blob/master/CONTRIBUTING.md).

We love getting pull requests! Anything from new features to documentation clean up.

If you're building a new carrier, a good place to start is in the [`Carrier` base class](https://github.com/Shopify/active_shipping/blob/master/lib/active_shipping/carrier.rb).

It would also be good to familiarize yourself with [`Location`](https://github.com/Shopify/active_shipping/blob/master/lib/active_shipping/location.rb), [`Package`](https://github.com/Shopify/active_shipping/blob/master/lib/active_shipping/package.rb), and [`Response`](https://github.com/Shopify/active_shipping/blob/master/lib/active_shipping/response.rb).

You can use the [`test/console.rb`](https://github.com/Shopify/active_shipping/blob/master/test/console.rb) to do some local testing against real endpoints.

To log requests and responses, just set the `logger` on your Carrier class to some kind of `Logger` object:

```ruby
ActiveShipping::USPS.logger = Logger.new(STDOUT)
```

### Anatomy of a pull request

Any new features or carriers should have passing unit _and_ remote tests. Look at some existing carriers as examples.

When opening a pull request, include description of the feature, why it exists, and any supporting documentation to explain interaction with carriers.


### How to contribute

1. Fork it ( https://github.com/Shopify/active_shipping/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

