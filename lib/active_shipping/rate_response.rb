module ActiveShipping
  class RateResponse < Response
    attr_reader :rates

    def initialize(success, message, params = {}, options = {})
      @rates = Array(options[:estimates] || options[:rates] || options[:rate_estimates])
      super
    end

    alias_method :estimates, :rates
    alias_method :rate_estimates, :rates
  end
end
