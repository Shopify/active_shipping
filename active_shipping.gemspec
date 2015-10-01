lib = File.expand_path('../lib/', __FILE__)
$:.unshift(lib) unless $:.include?(lib)

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
  s.license     = 'MIT'

  s.add_dependency('quantified',    '~> 1.0.1')
  s.add_dependency('activesupport', '>= 3.2', '< 5.0.0')
  s.add_dependency('active_utils',  '~> 3.1.0')
  s.add_dependency('nokogiri',      '>= 1.6')

  s.add_development_dependency('minitest')
  s.add_development_dependency('rake')
  s.add_development_dependency('mocha', '~> 1')
  s.add_development_dependency('timecop')
  s.add_development_dependency('business_time')
  s.add_development_dependency('pry')

  s.files        = `git ls-files`.split($/)
  s.executables  = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files   = s.files.grep(%r{^(test|spec|features)/})
  s.require_path = 'lib'
end
