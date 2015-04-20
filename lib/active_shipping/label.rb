module ActiveShipping
  class Label
    attr_reader :tracking_number, :base64_img_data

    def initialize(tracking_number, base64_img_data)
      @tracking_number = tracking_number
      @base64_img_data = base64_img_data
    end
  end
end
