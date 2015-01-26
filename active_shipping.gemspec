lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'active_shipping/version'

Gem::Specification.new do |s|
  s.name        = "active_shipping"
  s.version     = ActiveShipping::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["James MacAulay", "Tobi Lutke", "Cody Fauser", "Jimmy Baker"]
  s.email       = ["james@shopify.com"]
  s.homepage    = "http://github.com/shopify/active_shipping"
  s.summary     = "Simple shipping abstraction library"
  s.description = "Get rates and tracking info from various shipping carriers. Extracted from Shopify."

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "active_shipping"

  s.add_dependency('quantified',    '~> 1.0')
  s.add_dependency('activesupport', '>= 3.2', '< 5.0.0')
  s.add_dependency('active_utils',  '~> 3.0.0')
  s.add_dependency('builder',       '>= 2.1.2', '< 4.0.0')
  s.add_dependency('nokogiri',      '>= 1.6')

  s.add_development_dependency('minitest')
  s.add_development_dependency('rake')
  s.add_development_dependency('mocha', '~> 1')
  s.add_development_dependency('timecop')

  s.files        = Dir.glob("lib/**/*") + %w(MIT-LICENSE README.md CHANGELOG.md CONTRIBUTING.md)
  s.require_path = 'lib'
end
