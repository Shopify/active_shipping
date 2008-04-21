#!/usr/bin/env ruby
$:.unshift(File.dirname(__FILE__) + '/../lib')


require 'test/unit'
require 'active_shipping'

begin
  require 'mocha'
rescue LoadError
  require 'rubygems'
  require 'mocha'
end