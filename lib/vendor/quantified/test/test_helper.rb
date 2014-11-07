require 'test/unit'

begin
  require 'active_support/inflector'
rescue LoadError => e
  require 'rubygems'
  gem "activesupport", ">= 2.3.5"
  require 'active_support/inflector'
end

require File.dirname(__FILE__) + '/../lib/quantified'

class Test::Unit::TestCase
  EPSILON = 0.00001

  def assert_in_epsilon(expected, actual, msg = nil)
    assert_in_delta expected, actual, EPSILON, msg
  end
end
