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
        if options[:log_xml]
          log_options = (options[:log_xml].is_a?(Hash) ? options[:log_xml] : {})
          log_xml(log_options)
        end
        raise ResponseError.new(self) unless success
      end
    
      def success?
        @success ? true : false
      end

      def test?
        @test ? true : false
      end
      
      # options[:name] -- A name to give the log file. Defaults to a timestamp. The full filenames end up
      #                    being "#{name}_request.xml" and "#{name}_request.xml"
      # options[:path] -- The path to save the files. Defaults to
      #                    "~/.active_merchant/shipping/logs/#{carrier_name}". Directories will be
      #                    created if they don't exist already.
      def log_xml(options={})
        name = options[:name] || Time.new.strftime('%Y%m%d%H%M%S')
        carrier_name = begin
          self.rates.first.carrier
        rescue NoMethodError
          ''
        end
        path = options[:path] || File.join(ENV['HOME'], '.active_merchant', 'shipping', 'logs', carrier_name)
        File.makedirs(path)
        methods = {'request' => 'request', 'response' => 'xml'}
        methods.each do |suffix, method|
          file = File.join(path, ([name,suffix].join('_') + '.xml'))
          i = 0
          while File.exist?(file) do
            file = File.join(path, ([name + (i += 1).to_s,suffix].join('_') + '.xml'))
          end
          File.open(file, 'w+') do |file|
            file.puts self.send(method)
          end
        end
      end
      
    end
  end
end
