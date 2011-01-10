lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'active_shipping/version'

Gem::Specification.new do |s|
  s.name        = "active_shipping"
  s.version     = ActiveShipping::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["James MacAulay", "Tobi Lutke", "Cody Fauser", "Jimmy Baker"]
  s.email       = ["james@shopify.com"]
  s.version     = '0.9.6'
  s.homepage    = "http://github.com/shopify/active_shipping"
  s.summary     = "Shipping API extension for Active Merchant"
  s.description = "Get rates and tracking info from various shipping carriers."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "active_shipping"

  s.add_dependency('activesupport', '>= 2.3.5')

  s.add_development_dependency "mocha"

  s.files        = Dir.glob("lib/**/*") + %w(MIT-LICENSE README.markdown CHANGELOG)
  s.require_path = 'lib'
end