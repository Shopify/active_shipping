require 'test_helper'

class ShipmentEventTest < Minitest::Test
  def test_equality
    options1 = [
      'ARRIVED AT UNIT',
      DateTime.new(2016, 5, 12, 5, 45),
      Location.new(city: 'SAN JOSE', state: 'CA', postal_code: '90001', country: 'US'),
      'ARRIVED AT UNIT',
      '07'
    ]
    # Copies options to create new DateTime and Location objects to check for similar distinct objects
    options2 = options1.dup

    shipment_event_1 = ShipmentEvent.new(*options1)
    shipment_event_2 = ShipmentEvent.new(*options2)

    assert_equal shipment_event_1, shipment_event_2
  end
end
