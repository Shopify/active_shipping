# Active Shipping

This library is meant to interface with the web services of various shipping carriers. The goal is to abstract the features that are most frequently used into a pleasant and consistent Ruby API. Active Shipping is an extension of [Active Merchant][], and as such, it borrows heavily from conventions used in the latter.

We are starting out by only implementing the ability to list available shipping rates for a particular origin, destination, and set of packages. Further development could take advantage of other common features of carriers' web services such as tracking orders and printing labels.

Active Shipping is currently being used and improved in a production environment for the e-commerce application [Shopify][]. Development is being done by [James MacAulay][] (<james@jadedpixel.com>). Discussion is welcome in the [Active Merchant Google Group][discuss].

[Active Merchant]:http://www.activemerchant.org
[Shopify]:http://www.shopify.com
[James MacAulay]:http://jmacaulay.net
[discuss]:http://groups.google.com/group/activemerchant

## Supported Shipping Carriers

* [USPS](http://www.usps.com)
* more soon!

## Prerequisites

* [active_support](http://github.com/rails/rails/tree/master/activesupport)
* [xml_node](http://github.com/tobi/xml_node/) (right now a version of it is actually included in this library, so you don't need to worry about it yet)
* [mocha](http://mocha.rubyforge.org/) for the tests

## Download & Installation

Currently this library is available on GitHub:

  <http://github.com/Shopify/active_shipping>

You will need to get [Git][] if you don't have it. Then:

  > git clone git://github.com/Shopify/active_shipping.git

(That URL is case-sensitive, so watch out.)
  
Active Shipping includes an init.rb file. This means that Rails will automatically load it on startup. Check out [git-archive][] for exporting the file tree from your repository to your vendor directory.

Gem and tarball forthcoming on rubyforge.
  
[Git]:http://git.or.cz/
[git-archive]:http://www.kernel.org/pub/software/scm/git/docs/git-archive.html

## Sample Usage

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

## TODO

* proper documentation
* proper offline testing for carriers in addition to the remote tests
* package into a gem
* carrier code template generator
* more carriers
* integrate with ActiveMerchant
* support more features for existing carriers
* bin-packing algorithm (preferably implemented in ruby)
* order tracking
* label printing

## Contributing

Yes, please! Take a look at the tests and the implementation of the Carrier class to see how the basics work. At some point soon there will be a carrier template generator along the lines of the gateway generator included in Active Merchant, but carrier.rb outlines most of what's necessary. The other main classes that would be good to familiarize yourself with are Location, Package, and Response.

The nicest way to submit changes would be to set up a GitHub account and fork this project, then initiate a pull request when you want your changes looked at. You can also make a patch (preferably with [git-diff][]) and email to james@jadedpixel.com.

[git-diff]:http://www.kernel.org/pub/software/scm/git/docs/git-diff.html

## Contributors

* Tobias Luetke (<http://blog.leetsoft.com>)
* Cody Fauser (<http://codyfauser.com>)

## Legal Mumbo Jumbo

Unless otherwise noted in specific files, all code in the Active Shipping project is under the copyright and license described in the included MIT-LICENSE file.