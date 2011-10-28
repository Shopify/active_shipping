# Active Shipping

This library interfaces with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API. Active Shipping is an extension of [Active Merchant][], and as such, it borrows heavily from conventions used in the latter.

Active Shipping is currently being used and improved in a production environment for [Shopify][]. Development is being done by the Shopify integrations team (<integrations-team@shopify.com>). Discussion is welcome in the [Active Merchant Google Group][discuss].

[Active Merchant]:http://www.activemerchant.org
[Shopify]:http://www.shopify.com
[discuss]:http://groups.google.com/group/activemerchant

## Supported Shipping Carriers

* [USPS](http://www.usps.com)
* [FedEx](http://www.fedex.com)
* [Canada Post](http://www.canadapost.ca)
* [New Zealand Post](http://www.nzpost.co.nz)
* more soon!

## Installation

    gem install active_shipping

...or add it to your [Gemfile](http://gembundler.com/).

## Sample Usage

### Compare rates from different carriers

    require 'active_shipping'
    include ActiveMerchant::Shipping
  
    # Package up a poster and a Wii for your nephew.
    packages = [
      Package.new(  100,                        # 100 grams
                    [93,10],                    # 93 cm long, 10 cm diameter
                    :cylinder => true),         # cylinders have different volume calculations
    
      Package.new(  (7.5 * 16),                 # 7.5 lbs, times 16 oz/lb.
                    [15, 10, 4.5],              # 15x10x4.5 inches
                    :units => :imperial)        # not grams, not centimetres
    ]
  
    # You live in Beverly Hills, he lives in Ottawa
    origin = Location.new(      :country => 'US',
                                :state => 'CA',
                                :city => 'Beverly Hills',
                                :zip => '90210')
  
    destination = Location.new( :country => 'CA',
                                :province => 'ON',
                                :city => 'Ottawa',
                                :postal_code => 'K1P 1J1')
                              
    # Find out how much it'll be.
    usps = USPS.new(:login => 'developer-key')
    response = usps.find_rates(origin, destination, packages)
  
    usps_rates = response.rates.sort_by(&:price).collect {|rate| [rate.service_name, rate.price]}
    # => [["USPS Priority Mail International", 4110],
    #     ["USPS Express Mail International (EMS)", 5750],
    #     ["USPS Global Express Guaranteed Non-Document Non-Rectangular", 9400],
    #     ["USPS GXG Envelopes", 9400],
    #     ["USPS Global Express Guaranteed Non-Document Rectangular", 9400],
    #     ["USPS Global Express Guaranteed", 9400]]
    
### Track a FedEx package

    fedex = FedEx.new(:login => '999999999', :password => '7777777')
    tracking_info = fedex.find_tracking_info('tracking-number', :carrier_code => 'fedex_ground') # Ground package
    
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

## Running the tests

After installing dependencies with `bundle install`, you can run the unit tests with `rake test:units` and the remote tests with `rake test:remote`. The unit tests mock out requests and responses so that everything runs locally, while the remote tests actually hit the carrier servers. For the remote tests, you'll need valid test credentials for any carriers' tests you want to run. The credentials should go in ~/.active_merchant/fixtures.yml, and the format of that file can be seen in the included [fixtures.yml](https://github.com/Shopify/active_shipping/blob/master/test/fixtures.yml).

For the features you add, you should have both unit tests and remote tests. It's probably best to start with the remote tests, and then log those requests and responses and use them as the mocks for the unit tests. You can see how this works with the USPS tests right now:

https://github.com/Shopify/active_shipping/blob/master/test/remote/usps_test.rb
https://github.com/Shopify/active_shipping/blob/master/test/unit/carriers/usps_test.rb
https://github.com/Shopify/active_shipping/tree/master/test/fixtures/xml/usps

To log requests and responses, just set the `logger` on your carrier class to some kind of `Logger` object:

    USPS.logger = Logger.new($stdout)

(This logging functionality is provided by the [`PostsData` module](https://github.com/Shopify/active_utils/blob/master/lib/active_utils/common/posts_data.rb) in the `active_utils` dependency.)


## Contributing

Yes, please! Take a look at the tests and the implementation of the Carrier class to see how the basics work. At some point soon there will be a carrier template generator along the lines of the gateway generator included in Active Merchant, but carrier.rb outlines most of what's necessary. The other main classes that would be good to familiarize yourself with are Location, Package, and Response.

After you've made your well-tested changes in your github fork, make a pull request and we'll take it from there!

## Contributors

* James MacAulay (<http://jmacaulay.net>)
* Tobias Luetke (<http://blog.leetsoft.com>)
* Cody Fauser (<http://codyfauser.com>)
* Jimmy Baker (<http://jimmyville.com/>)
* William Lang (<http://williamlang.net/>)

## Legal Mumbo Jumbo

Unless otherwise noted in specific files, all code in the Active Shipping project is under the copyright and license described in the included MIT-LICENSE file.
