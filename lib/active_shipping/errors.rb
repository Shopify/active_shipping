module ActiveShipping
  class Error < ActiveUtils::ActiveUtilsError
  end

  class ResponseError < ActiveShipping::Error
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

  class ResponseContentError < ActiveShipping::Error
    def initialize(exception, content_body = nil)
      super([exception.message, content_body].compact.join(" \n\n"))
    end
  end

  class ShipmentNotFound < ActiveShipping::Error
  end
end
