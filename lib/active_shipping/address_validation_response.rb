module ActiveShipping

  # Response object class for calls to {ActiveShipping::Carrier#validate_address}.
  # 
  # @!attribute location
  #   The Location to be validated
  #   @return [String]
  class AddressValidationResponse < Response
    attr_reader :validity, :classification, :candidate_addresses, :options, :params

    def initialize(success, message, params = {}, options = {})
      @validity = options[:validity]
      @candidate_addresses = options[:candidate_addresses]
      @classification = options[:classification]
      super
    end

    def address_match?
      @validity == :valid
    end

    def residential?
      @classification == :residential
    end

    def commercial?
      @classification == :commercial
    end
  end
end
