#--
# Copyright (c) 2009 Jaded Pixel
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

$:.unshift File.dirname(__FILE__)

begin
  require 'active_support/all'
rescue LoadError => e
  require 'rubygems'
  gem "activesupport", ">= 2.3.5"
  require "active_support/all"
end

require 'vendor/xml_node/lib/xml_node'
require 'vendor/quantified/lib/quantified'
require 'quantified/mass'
require 'quantified/length'

require 'net/https'
require 'active_shipping/lib/error'
require 'active_shipping/lib/requires_parameters'
require 'active_shipping/lib/connection'
require 'active_shipping/lib/posts_data'
require 'active_shipping/lib/country'

require 'active_shipping/shipping/base'
require 'active_shipping/shipping/response'
require 'active_shipping/shipping/rate_response'
require 'active_shipping/shipping/tracking_response'
require 'active_shipping/shipping/package'
require 'active_shipping/shipping/location'
require 'active_shipping/shipping/rate_estimate'
require 'active_shipping/shipping/shipment_event'
require 'active_shipping/shipping/carrier'
require 'active_shipping/shipping/carriers'
