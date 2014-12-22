module ActiveShipping
  class ResponseContentError < StandardError
    def initialize(exception, content_body)
      super("#{exception.message} \n\n#{content_body}")
    end
  end
end
