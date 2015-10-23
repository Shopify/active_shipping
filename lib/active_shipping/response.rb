module ActiveShipping #:nodoc:

  # Basic Response class for requests against a carrier's API.
  class Response
    attr_reader :params
    attr_reader :message
    attr_reader :test
    attr_reader :xml
    attr_reader :request

    # @param success [Boolean] Whether the request was considered successful, i.e. this
    #   response object will have the expected data set.
    # @param message [String] A status message. Usuaully set when `success` is `false`,
    #   but can also be set for successful responses.
    # @param params [Hash] Response parameters
    # @param options [Hash]
    # @option options [Boolean] :test (default: false) Whether this reponse was a result
    #   of a request executed against the sandbox or test environment of the carrier's API.
    # @option options [String] :xml The raw XML of the response.
    # @option options [String] :request The payload of the request.
    # @option options [Boolean] :allow_failure Allows a failed response without raising.
    def initialize(success, message, params = {}, options = {})
      @success, @message, @params = success, message, params.stringify_keys
      @test = options[:test] || false
      @xml = options[:xml]
      @request = options[:request]
      raise ResponseError.new(self) unless success || options[:allow_failure]
    end

    # Whether the request was executed successfully or not.
    # @return [Boolean] Should only return `true` if the attributes of teh response
    #   instance are set with useful values.
    def success?
      @success ? true : false
    end

    # Whether this request was executed against the sandbox or test environment instead of
    # the production environment of the carrier.
    # @return [Boolean]
    def test?
      @test ? true : false
    end
  end
end
