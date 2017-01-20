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

  s.add_dependency("measured", "~> 1.6.0")
  s.add_dependency("activesupport", ">= 4.2", "< 5.1.0")
  s.add_dependency("active_utils", "~> 3.2.0")
  s.add_dependency("nokogiri", ">= 1.6")

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
