module ActiveMerchant #:nodoc:
  
  class ActiveMerchantError < StandardError #:nodoc:
  end
  
  module Shipping #:nodoc:
    
    class Error < ActiveMerchant::ActiveMerchantError
    end
    
    class ResponseError < Error
      attr_reader :response
      
      def initialize(response = nil)
        if response.is_a? Response
          super(response.message)
          @response = response
        else
          super(response)
        end
      end      
    end
    
    class Response
      
      attr_reader :params
      attr_reader :message
      attr_reader :test
      attr_reader :xml
      attr_reader :request
        
      def initialize(success, message, params = {}, options = {})
        @success, @message, @params = success, message, params.stringify_keys
        @test = options[:test] || false
        @xml = options[:xml]
        @request = options[:request]
        raise ResponseError.new(self) unless success
      end
    
      def success?
        @success ? true : false
      end

      def test?
        @test ? true : false
      end
      
    end
  end
end
