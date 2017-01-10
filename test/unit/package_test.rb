require 'test_helper'

class PackageTest < ActiveSupport::TestCase
  setup do
    @weight = 100
    @dimensions = [5, 6, 7]
    @value = 1299
    @currency = "USD"
    @cylinder = false
    @tube = false
    @gift = false
    @oversized = false
    @unpackaged = false
    @dim_units = :metric
    @units = :metric
    @weight_units = :metric
    @options = {
      value: @value,
      currency:  @currency,
      cylinder: @cylinder,
      tube: @tube,
      gift: @gift,
      oversized: @oversized,
      unpackaged: @unpackaged,
      dim_units: @dim_units,
      units: @units,
      weight_units: @weight_units,
    }

    @package = Package.new(@weight, @dimensions, @options)
    @imperial_package = Package.new(@weight, @dimensions, @options.merge(units: :imperial, dim_units: :imperial, weight_units: :imperial))

    @mass = Measured::Weight.new(@weight, :grams)
  end

  test "#initialize package from mass" do
    ten_pounds = Measured::Weight.new(10, :pounds)
    package = Package.new(ten_pounds, [])
    assert_equal ten_pounds, package.weight
  end

  test "#initialize with defaults" do
    assert_equal @value, @package.value
    assert_equal @currency, @package.currency
    assert_equal @cylinder, @package.cylinder?
    assert_equal @tube, @package.tube?
    assert_equal @oversized, @package.oversized?
    assert_equal @unpackaged, @package.unpackaged?
    assert_equal @gift, @package.gift?
  end

  test "#initialize with currency cents" do
    @package = Package.new(@weight, @dimensions, value: money)
    assert_equal @currency, @package.currency
    assert_equal @value, @package.value
  end

  test "#initialize sorts the passed in dimensions" do
    @package = Package.new(@weight, [9, 8, 7], @options)

    assert_equal [7, 8, 9], @package.centimetres
  end

  test "#initialize sets default dimensions if blank" do
    @package = Package.new(@weight, [], @options)

    assert_equal [0, 0, 0], @package.centimetres
  end

  test "#initialize increases dimension size to three elements in the array and pads" do
    @package = Package.new(@weight, [2], @options)

    assert_equal [2, 2, 2], @package.centimetres
  end

  test "#initialize default units" do
    assert_equal @dimensions, @package.centimetres
    assert_equal @weight, @package.grams
  end

  test "#initialize units" do
    assert_equal @dimensions, @imperial_package.inches
  end

  test "#initialize weight_units" do
    @package = Package.new(@weight, @dimensions, @options.merge(weight_units: :imperial))

    assert_equal @weight, @package.ounces
  end

  test "#unpackaged?" do
    assert_predicate Package.new(@weight, @dimensions, unpackaged: true), :unpackaged?
    refute_predicate Package.new(@weight, @dimensions, unpackaged: false), :unpackaged?
  end

  test "#oversized?" do
    assert_predicate Package.new(@weight, @dimensions, oversized: true), :oversized?
    refute_predicate Package.new(@weight, @dimensions, oversized: false), :oversized?
  end

  test "#gift?" do
    assert_predicate Package.new(@weight, @dimensions, gift: true), :gift?
    refute_predicate Package.new(@weight, @dimensions, gift: false), :gift?
  end

  test "#cylinder? and #tube? check both values" do
    @package = Package.new(@weight, @dimensions, cylinder: false, tube: false)
    refute_predicate @package, :cylinder?
    refute_predicate @package, :tube?

    @package = Package.new(@weight, @dimensions, cylinder: true, tube: false)
    assert_predicate @package, :cylinder?
    assert_predicate @package, :tube?

    @package = Package.new(@weight, @dimensions, cylinder: false, tube: true)
    assert_predicate @package, :cylinder?
    assert_predicate @package, :tube?

    @package = Package.new(@weight, @dimensions, cylinder: true, tube: true)
    assert_predicate @package, :cylinder?
    assert_predicate @package, :tube?
  end

  test "#inches performs lookup with a numerical index" do
    assert_equal @dimensions[0], @imperial_package.inches(0)
    assert_equal @dimensions[1], @imperial_package.inches(1)
    assert_equal @dimensions[2], @imperial_package.inches(2)
    assert_nil @imperial_package.inches(3)
  end

  test "#inches for dimension x" do
    assert_equal @dimensions[2], @imperial_package.inches(:x)
    assert_equal @dimensions[2], @imperial_package.inches(:max)
    assert_equal @dimensions[2], @imperial_package.inches(:length)
    assert_equal @dimensions[2], @imperial_package.inches(:long)
  end

  test "#inches for dimension y" do
    assert_equal @dimensions[1], @imperial_package.inches(:y)
    assert_equal @dimensions[1], @imperial_package.inches(:mid)
    assert_equal @dimensions[1], @imperial_package.inches(:width)
    assert_equal @dimensions[1], @imperial_package.inches(:wide)
  end

  test "#inches for dimension z" do
    assert_equal @dimensions[0], @imperial_package.inches(:z)
    assert_equal @dimensions[0], @imperial_package.inches(:min)
    assert_equal @dimensions[0], @imperial_package.inches(:height)
    assert_equal @dimensions[0], @imperial_package.inches(:depth)
    assert_equal @dimensions[0], @imperial_package.inches(:high)
    assert_equal @dimensions[0], @imperial_package.inches(:deep)
  end

  test "#inches for girth of a cylinder" do
    @imperial_package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :imperial, dim_units: :imperial))

    assert_predicate @imperial_package, :cylinder?
    assert_in_delta 17.2, @imperial_package.inches(:girth), 1
    assert_in_delta 17.2, @imperial_package.inches(:around), 1
    assert_in_delta 17.2, @imperial_package.inches(:circumference), 1

  end

  test "#inches for girth of a non cylinder" do
    refute_predicate @imperial_package, :cylinder?
    assert_in_delta 22, @imperial_package.inches(:girth), 1
    assert_in_delta 22, @imperial_package.inches(:around), 1
    assert_in_delta 22, @imperial_package.inches(:circumference), 1
  end

  test "#inches for the volume of a cylinder" do
    @imperial_package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :imperial, dim_units: :imperial))

    assert_predicate @imperial_package, :cylinder?
    assert_in_delta 522.4, @imperial_package.inches(:volume), 1
  end

  test "#inches for volume" do
    refute_predicate @imperial_package, :cylinder?
    assert_equal 210, @imperial_package.inches(:volume)
  end

  test "#inches for box_volume" do
    assert_equal 210, @imperial_package.inches(:box_volume)
  end

  test "#inches of an unknown value" do
    assert_nil @imperial_package.inches(:unknown)
  end

  test "#inches alias to #in" do
    assert_equal @dimensions, @imperial_package.inches
    assert_equal @dimensions, @imperial_package.in
  end

  test "#centimetres performs lookup with a numerical index" do
    assert_equal @dimensions[0], @package.centimetres(0)
    assert_equal @dimensions[1], @package.centimetres(1)
    assert_equal @dimensions[2], @package.centimetres(2)
    assert_nil @package.centimetres(3)
  end

  test "#centimetres for dimension x" do
    assert_equal @dimensions[2], @package.centimetres(:x)
    assert_equal @dimensions[2], @package.centimetres(:max)
    assert_equal @dimensions[2], @package.centimetres(:length)
    assert_equal @dimensions[2], @package.centimetres(:long)
  end

  test "#centimetres for dimension y" do
    assert_equal @dimensions[1], @package.centimetres(:y)
    assert_equal @dimensions[1], @package.centimetres(:mid)
    assert_equal @dimensions[1], @package.centimetres(:width)
    assert_equal @dimensions[1], @package.centimetres(:wide)
  end

  test "#centimetres for dimension z" do
    assert_equal @dimensions[0], @package.centimetres(:z)
    assert_equal @dimensions[0], @package.centimetres(:min)
    assert_equal @dimensions[0], @package.centimetres(:height)
    assert_equal @dimensions[0], @package.centimetres(:depth)
    assert_equal @dimensions[0], @package.centimetres(:high)
    assert_equal @dimensions[0], @package.centimetres(:deep)
  end

  test "#centimetres for girth of a cylinder" do
    @package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :metric, dim_units: :metric))

    assert_predicate @package, :cylinder?
    assert_in_delta 17.2, @package.centimetres(:girth), 1
    assert_in_delta 17.2, @package.centimetres(:around), 1
    assert_in_delta 17.2, @package.centimetres(:circumference), 1

  end

  test "#centimetres for girth of a non-cylinder" do
    refute_predicate @package, :cylinder?
    assert_in_delta 22, @package.centimetres(:girth), 1
    assert_in_delta 22, @package.centimetres(:around), 1
    assert_in_delta 22, @package.centimetres(:circumference), 1
  end

  test "#centimetres for the volume of a cylinder" do
    @package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :metric, dim_units: :metric))

    assert_predicate @package, :cylinder?
    assert_in_delta 522.4, @package.centimetres(:volume), 1
  end

  test "#centimetres for volume" do
    refute_predicate @package, :cylinder?
    assert_equal 210, @package.centimetres(:volume)
  end

  test "#centimetres for box_volume" do
    assert_equal 210, @package.centimetres(:box_volume)
  end

  test "#centimetres of an unknown value" do
    assert_nil @package.centimetres(:unknown)
  end

  test "#centimetres alias to #cm" do
    assert_equal @dimensions, @package.centimetres
    assert_equal @dimensions, @package.cm
  end

  test "#weight" do
    assert_equal @mass, @package.weight
    assert_instance_of Measured::Weight, @package.weight
  end

  test "#weight for actual" do
    assert_equal @mass, @package.weight(type: :actual)
    assert_instance_of Measured::Weight, @package.weight(type: :actual)
  end

  test "#weight volumetric" do
    assert_equal Measured::Weight.new(35, :grams), @package.weight(type: :volumetric)
  end

  test "#weight dimensional" do
    assert_equal Measured::Weight.new(35, :grams), @package.weight(type: :dimensional)
  end

  test "#weight billable is the max of weight and volumetric" do
    assert_equal Measured::Weight.new(100, :grams), @package.weight(type: :billable)

    @package = Package.new(500, [1, 1, 1], @options)
    assert_equal Measured::Weight.new(500, :grams), @package.weight(type: :billable)
  end

  test "#grams value" do
    assert_equal 100, @package.grams
  end

  test "#grams accepts options with type" do
    assert_in_delta 35, @package.grams(type: :volumetric), 1
  end

  test "#grams converts to another unit from another system" do
    @package = Package.new(@weight, @dimensions, weight_units: :imperial)

    assert_in_delta 2834.9, @package.grams, 1
  end

  test "#grams alias to #g" do
    assert_equal @package.grams, @package.g
  end

  test "#ounces value" do
    assert_equal 100, @imperial_package.ounces
  end

  test "#ounces accepts options with type" do
    assert_in_delta 20.2, @imperial_package.ounces(type: :volumetric), 1
  end

  test "#ounces converts to another unit from another system" do
    assert_in_delta 3.5, @package.ounces, 1
  end

  test "#ounces alias to #oz" do
    assert_equal @imperial_package.ounces, @imperial_package.oz
  end

  test "#pounds value" do
    assert_equal 6.25, @imperial_package.pounds
  end

  test "#pounds accepts options with type" do
    assert_in_delta 0.07, @package.pounds(type: :volumetric), 0.01
  end

  test "#pounds converts to another unit from another system" do
    assert_in_delta 0.22, @package.pounds, 0.01
  end

  test "#pounds alias to #lb" do
    assert_equal @package.pounds, @package.lb
  end

  test "#pounds alias to #lbs" do
    assert_equal @package.pounds, @package.lbs
  end

  test "#kilograms value" do
    assert_equal 0.1, @package.kilograms
  end

  test "#kilograms accepts options with type" do
    assert_equal 0.035, @package.kilograms(type: :volumetric)
  end

  test "#kilograms converts to another unit from another system" do
    assert_in_delta 2.8, @imperial_package.kilograms, 1
  end

  test "#kilograms alias to #kg" do
    assert_equal 0.1, @package.kg
  end

  test "#kilograms alias to #kgs" do
    assert_equal @package.kilograms, @package.kgs
  end

  test ".cents_from nil" do
    assert_nil Package.cents_from(nil)
  end

  test ".cents_from cents on a money object" do
    assert_equal @value, Package.cents_from(money)
  end

  test ".cents_from float" do
    assert_equal 120, Package.cents_from(1.2)
  end

  test ".cents_from string" do
    assert_equal 120, Package.cents_from("1.20")
  end

  test ".cents_from integer" do
    assert_equal 12, Package.cents_from(12)
  end

  test ".cents_from an unhandled object" do
    exception = assert_raises NoMethodError do
      Package.cents_from(Object.new)
    end
    assert_match /undefined method `to_i'/, exception.message
  end

  private

  def money
    @money ||= begin
      value = Class.new { attr_accessor :currency, :cents }.new
      value.currency = @currency
      value.cents = @value
      value
    end
  end
end
