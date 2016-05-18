require 'test_helper'

class TrackingResponseTest < Minitest::Test
  def test_equality
    options1 = {
      carrier: 'usps',
      status: 'DELIVERED',
      status_code: 'I0',
      status_description: 'DELIVERED',
      actual_delivery_date: DateTime.new(2016, 5, 14, 13, 20),
      tracking_number: 'TRACKINGNUMBER1234ABC',
      shipment_events: [
        ShipmentEvent.new(
          'DELIVERED',
          DateTime.new(2016, 5, 14, 13, 20),
          Location.new(city: 'LOS ANGELES', state: 'CA', postal_code: '90210', country: 'US'),
          'DELIVERED',
          'I0'
        ),
        ShipmentEvent.new(
          'ARRIVED AT UNIT',
          DateTime.new(2016, 5, 12, 5, 45),
          Location.new(city: 'SAN JOSE', state: 'CA', postal_code: '90001', country: 'US'),
          'ARRIVED AT UNIT',
          '07'
        )
      ],
      destination: Location.new(postal_code: '90210'),
      origin: Location.new(postal_code: '00001')
    }
    # Deep copies options1 to create new ShipmentEvent, Location, etc. objects to check for similar distinct objects
    options2 = Marshal.load(Marshal.dump(options1))
    options2[:shipment_events][0], options2[:shipment_events][1] =
      options2[:shipment_events][1], options2[:shipment_events][0]

    tracking_response_1 = TrackingResponse.new(true, nil, {}, options1)
    tracking_response_2 = TrackingResponse.new(true, nil, {}, options2)

    assert_equal tracking_response_1, tracking_response_2
  end
end
