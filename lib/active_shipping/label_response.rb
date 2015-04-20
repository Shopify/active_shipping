module ActiveShipping
  class LabelResponse < Response
    attr_reader :labels

    def initialize(success, message, params = {}, options = {})
      @labels = options[:labels]
      super
    end
  end
end
