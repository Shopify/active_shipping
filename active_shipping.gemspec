lib = File.expand_path("../lib/", __FILE__)
$:.unshift(lib) unless $:.include?(lib)

require "active_shipping/version"

Gem::Specification.new do |s|
  s.name          = "active_shipping"
  s.version       = ActiveShipping::VERSION
  s.platform      = Gem::Platform::RUBY
  s.authors       = ["Shopify"]
  s.email         = ["integrations-team@shopify.com"]
  s.homepage      = "http://github.com/shopify/active_shipping"
  s.summary       = "Simple shipping abstraction library"
  s.description   = "Get rates and tracking info from various shipping carriers. Extracted from Shopify."
  s.license       = "MIT"
  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_path  = "lib"
  s.post_install_message = "Thanks for installing ActiveShipping! If upgrading to v2.0, please see the changelog for breaking changes: https://github.com/Shopify/active_shipping/blob/master/CHANGELOG.md."

  s.add_dependency("measured", ">= 2.0")
  s.add_dependency("activesupport", ">= 4.2", "< 5.2.0")
  s.add_dependency("active_utils", "~> 3.3.1")
  s.add_dependency("nokogiri", ">= 1.7.1")

  s.add_development_dependency("minitest")
  s.add_development_dependency("minitest-reporters")
  s.add_development_dependency("rake")
  s.add_development_dependency("mocha", "~> 1")
  s.add_development_dependency("timecop")
  s.add_development_dependency("business_time")
  s.add_development_dependency("pry")
  s.add_development_dependency("pry-byebug")
  s.add_development_dependency("vcr")
  s.add_development_dependency("webmock")
end
