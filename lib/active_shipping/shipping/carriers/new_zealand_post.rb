require 'ruby-debug'

module ActiveMerchant
  module Shipping
    class NewZealandPost < Carrier

      # class NewZealandPostRateResponse < RateResponse
      # end
      
      @@name = "NewZealandPost"

      URL = "http://workshop.nzpost.co.nz/api/v1/rate.xml"

      # Override to return required keys in options hash for initialize method.
      def requirements
        [:api_key]
      end

      # Override with whatever you need to get the rates
      def find_rates(origin, destination, packages, options = {})
        packages = Array(packages)
        cost_estimates = {}
        packages.each do |package|
          request_hash = build_rectangular_request_params(origin, destination, package, options)
          url = URL + '?' + request_hash.to_param
          @response = ssl_get(url)
          xml = REXML::Document.new(@response)
          if response_success?(xml)
            xml.elements.each('hash/products/product') do |prod|
              service_code = prod.get_text('service').to_s
              (cost_estimates[service_code.to_sym] ||= []) << {:cost => prod.get_text('cost').to_s.to_f,
                :service_group_description => prod.get_text('service-group-description')}
            end
          else
            error_message = response_message(xml)
            return RateResponse.new(false, error_message, Hash.from_xml(@response), :rates => [], :xml => @response)
          end
        end

        #if there isnt a shipping option for every package, ignore that
        #shipping option
        cost_estimates.delete_if{ |k,v| v.size != packages.size }
        rate_estimates = []
        cost_estimates.each do |service_code,costs|
          cost = costs.inject(0){ |sum, c| sum = sum + c[:cost] }
          service_group_description = costs.first[:service_group_description]
          rate_estimates << RateEstimate.new(origin, destination, @@name, service_group_description,
                                             :total_price => cost,
                                             :currency => 'NZD',
                                             :service_code => service_code,
                                             :packages => packages)
        end
        RateResponse.new(true, "Success", Hash.from_xml(@response), :rates => rate_estimates, :xml => @response)
      end

      def maximum_weight
        Mass.new(20, :kilograms)
      end

      protected

      # Override in subclasses for non-U.S.-based carriers.
      def self.default_location
        Location.new(:postal_code => '6011')
      end

      private

      def build_rectangular_request_params(origin, destination,  package, options = {})
        params = {
          :postcode_src => origin.postal_code,
          :postcode_dest => destination.postal_code,
          :api_key => @options[:api_key],
          :height => "#{package.centimetres(:height) * 10}",
          :thickness => "#{package.centimetres(:width) * 10}",
          :length => "#{package.centimetres(:length) * 10}",
          :weight =>"%.1f" % (package.weight.amount / 1000.0)
        }
      end

      #def parse_rate_response(origin, destination, packages, response, options={})
        #xml = REXML::Document.new(response)
        #if response_success?(xml)
          #rate_estimates = []
          #xml.elements.each('hash/products/product') do |prod|
            #rate_estimates << RateEstimate.new(origin, 
                                               #destination,
                                               #@@name,
                                               #prod.get_text('service-group-description').to_s,
                                               #:total_price => prod.get_text('cost').to_s.to_f,
                                               #:currency => 'NZD',
                                               #:service_code => prod.get_text('service').to_s,
                                               #:packages => packages)
          #end
          
          #RateResponse.new(true, "Success", Hash.from_xml(response), :rates => rate_estimates, :xml => response)
        #else
          #error_message = response_message(xml)
          #RateResponse.new(false, error_message, Hash.from_xml(response), :rates => rate_estimates, :xml => response)
        #end
      #end

      def response_success?(xml)
        xml.get_text('hash/status').to_s == 'success'
      end

      def response_message(xml)
        if response_success?(xml)
          'Success'
        else
          xml.get_text('hash/message').to_s
        end
      end

    end
  end
end
