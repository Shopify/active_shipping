require 'test/unit'
begin
  require 'active_support/inflector'
rescue LoadError => e
  require 'rubygems'
  gem "activesupport", ">= 2.3.5"
  require 'active_support/inflector'
end

require File.dirname(__FILE__) + '/../lib/quantified'
