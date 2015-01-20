module ActiveShipping
  class Carrier
    include ActiveUtils::RequiresParameters
    include ActiveUtils::PostsData
    include Quantified

    attr_reader :last_request
    attr_accessor :test_mode
    alias_method :test_mode?, :test_mode

    # Credentials should be in options hash under keys :login, :password and/or :key.
    def initialize(options = {})
      requirements.each { |key| requires!(options, key) }
      @options = options
      @last_request = nil
      @test_mode = @options[:test]
    end

    # Override to return required keys in options hash for initialize method.
    def requirements
      []
    end

    # Override with whatever you need to get the rates
    def find_rates(origin, destination, packages, options = {})
    end

    # Override with whatever you need to get a shipping label
    def create_shipment(origin, destination, packages, options = {})
    end

    # Validate credentials with a call to the API. By default this just does a find_rates call
    # with the orgin and destination both as the carrier's default_location. Override to provide
    # alternate functionality, such as checking for test_mode to use test servers, etc.
    def valid_credentials?
      location = self.class.default_location
      find_rates(location, location, Package.new(100, [5, 15, 30]), :test => test_mode)
    rescue ActiveShipping::ResponseError
      false
    else
      true
    end

    def maximum_weight
      Mass.new(150, :pounds)
    end

    protected

    # Override in subclasses for non-U.S.-based carriers.
    def self.default_location
      Location.new( :country => 'US',
                    :state => 'CA',
                    :city => 'Beverly Hills',
                    :address1 => '455 N. Rexford Dr.',
                    :address2 => '3rd Floor',
                    :zip => '90210',
                    :phone => '1-310-285-1013',
                    :fax => '1-310-275-8159')
    end

    # Use after building the request to save for later inspection. Probably won't ever be overridden.
    def save_request(r)
      @last_request = r
    end

    def timestamp_from_business_day(days)
      return unless days
      date = DateTime.now.utc
      days.times do
        begin
          date = date + 1
        end while [0, 6].include?(date.wday)
      end
      date
    end
  end
end
