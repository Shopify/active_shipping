module ActiveShipping
  class Label
    attr_reader :tracking_number, :img_data

    def initialize(tracking_number, img_data)
      @tracking_number = tracking_number
      @img_data = img_data
    end
  end
end
