require 'test_helper'

class PackageTest < ActiveSupport::TestCase
  def setup
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

    @mass = ::Quantified::Mass.new(@weight, :grams)
  end

  def test_package_from_mass
    package = Package.new(Quantified::Mass.new(10, :pounds), [])
    assert_equal 10, package.weight
  end

  def test_initialize_defaults
    assert_equal @value, @package.value
    assert_equal @currency, @package.currency
    assert_equal @cylinder, @package.cylinder?
    assert_equal @tube, @package.tube?
    assert_equal @oversized, @package.oversized?
    assert_equal @unpackaged, @package.unpackaged?
    assert_equal @gift, @package.gift?
  end

  def test_currency_cents
    @package = Package.new(@weight, @dimensions, value: money)
    assert_equal @currency, @package.currency
    assert_equal @value, @package.value
  end

  def test_initialize_sorted_dimensions
    @package = Package.new(@weight, [9, 8, 7], @options)

    assert_equal [7, 8, 9], @package.centimetres
  end

  def test_initialize_blank_dimensions
    @package = Package.new(@weight, [], @options)

    assert_equal [0, 0, 0], @package.centimetres
  end

  def test_initialize_increases_dimension_size_to_three
    @package = Package.new(@weight, [2], @options)

    assert_equal [2, 2, 2], @package.centimetres
  end

  def test_initialize_default_units
    assert_equal @dimensions, @package.centimetres
    assert_equal @weight, @package.grams
  end

  def test_initialize_units
    assert_equal @dimensions, @imperial_package.inches
  end

  def test_initialize_weight_units
    @package = Package.new(@weight, @dimensions, @options.merge(weight_units: :imperial))

    assert_equal @weight, @package.ounces
  end

  def test_unpackaged
    assert_predicate Package.new(@weight, @dimensions, unpackaged: true), :unpackaged?
    refute_predicate Package.new(@weight, @dimensions, unpackaged: false), :unpackaged?
  end

  def test_oversized
    assert_predicate Package.new(@weight, @dimensions, oversized: true), :oversized?
    refute_predicate Package.new(@weight, @dimensions, oversized: false), :oversized?
  end

  def test_gift
    assert_predicate Package.new(@weight, @dimensions, gift: true), :gift?
    refute_predicate Package.new(@weight, @dimensions, gift: false), :gift?
  end

  def test_cylinder_tube
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

  def test_inches_number_index
    assert_equal @dimensions[0], @imperial_package.inches(0)
    assert_equal @dimensions[1], @imperial_package.inches(1)
    assert_equal @dimensions[2], @imperial_package.inches(2)
    assert_nil @imperial_package.inches(3)
  end

  def test_inches_x
    assert_equal @dimensions[2], @imperial_package.inches(:x)
    assert_equal @dimensions[2], @imperial_package.inches(:max)
    assert_equal @dimensions[2], @imperial_package.inches(:length)
    assert_equal @dimensions[2], @imperial_package.inches(:long)
  end

  def test_inches_y
    assert_equal @dimensions[1], @imperial_package.inches(:y)
    assert_equal @dimensions[1], @imperial_package.inches(:mid)
    assert_equal @dimensions[1], @imperial_package.inches(:width)
    assert_equal @dimensions[1], @imperial_package.inches(:wide)
  end

  def test_inches_z
    assert_equal @dimensions[0], @imperial_package.inches(:z)
    assert_equal @dimensions[0], @imperial_package.inches(:min)
    assert_equal @dimensions[0], @imperial_package.inches(:height)
    assert_equal @dimensions[0], @imperial_package.inches(:depth)
    assert_equal @dimensions[0], @imperial_package.inches(:high)
    assert_equal @dimensions[0], @imperial_package.inches(:deep)
  end

  def test_inches_girth_cylinder
    @imperial_package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :imperial, dim_units: :imperial))

    assert_predicate @imperial_package, :cylinder?
    assert_in_delta 17.2, @imperial_package.inches(:girth), 1
    assert_in_delta 17.2, @imperial_package.inches(:around), 1
    assert_in_delta 17.2, @imperial_package.inches(:circumference), 1

  end

  def test_inches_girth
    refute_predicate @imperial_package, :cylinder?
    assert_in_delta 22, @imperial_package.inches(:girth), 1
    assert_in_delta 22, @imperial_package.inches(:around), 1
    assert_in_delta 22, @imperial_package.inches(:circumference), 1
  end

  def test_inches_volume_cylinder
    @imperial_package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :imperial, dim_units: :imperial))

    assert_predicate @imperial_package, :cylinder?
    assert_in_delta 522.4, @imperial_package.inches(:volume), 1
  end

  def test_inches_volume
    refute_predicate @imperial_package, :cylinder?
    assert_equal 210, @imperial_package.inches(:volume)
  end

  def test_inches_box_volume
    assert_equal 210, @imperial_package.inches(:box_volume)
  end

  def test_inches_unknown
    assert_nil @imperial_package.inches(:unknown)
  end

  def test_inches_alias_in
    assert_equal @dimensions, @imperial_package.inches
    assert_equal @dimensions, @imperial_package.in
  end

  def test_centimetres_number_index
    assert_equal @dimensions[0], @package.centimetres(0)
    assert_equal @dimensions[1], @package.centimetres(1)
    assert_equal @dimensions[2], @package.centimetres(2)
    assert_nil @package.centimetres(3)
  end

  def test_centimetres_x
    assert_equal @dimensions[2], @package.centimetres(:x)
    assert_equal @dimensions[2], @package.centimetres(:max)
    assert_equal @dimensions[2], @package.centimetres(:length)
    assert_equal @dimensions[2], @package.centimetres(:long)
  end

  def test_centimetres_y
    assert_equal @dimensions[1], @package.centimetres(:y)
    assert_equal @dimensions[1], @package.centimetres(:mid)
    assert_equal @dimensions[1], @package.centimetres(:width)
    assert_equal @dimensions[1], @package.centimetres(:wide)
  end

  def test_centimetres_z
    assert_equal @dimensions[0], @package.centimetres(:z)
    assert_equal @dimensions[0], @package.centimetres(:min)
    assert_equal @dimensions[0], @package.centimetres(:height)
    assert_equal @dimensions[0], @package.centimetres(:depth)
    assert_equal @dimensions[0], @package.centimetres(:high)
    assert_equal @dimensions[0], @package.centimetres(:deep)
  end

  def test_centimetres_girth_cylinder
    @package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :metric, dim_units: :metric))

    assert_predicate @package, :cylinder?
    assert_in_delta 17.2, @package.centimetres(:girth), 1
    assert_in_delta 17.2, @package.centimetres(:around), 1
    assert_in_delta 17.2, @package.centimetres(:circumference), 1

  end

  def test_centimetres_girth
    refute_predicate @package, :cylinder?
    assert_in_delta 22, @package.centimetres(:girth), 1
    assert_in_delta 22, @package.centimetres(:around), 1
    assert_in_delta 22, @package.centimetres(:circumference), 1
  end

  def test_centimetres_volume_cylinder
    @package = Package.new(@weight, @dimensions, @options.merge(cylinder: true, units: :metric, dim_units: :metric))

    assert_predicate @package, :cylinder?
    assert_in_delta 522.4, @package.centimetres(:volume), 1
  end

  def test_centimetres_volume
    refute_predicate @package, :cylinder?
    assert_equal 210, @package.centimetres(:volume)
  end

  def test_centimetres_box_volume
    assert_equal 210, @package.centimetres(:box_volume)
  end

  def test_centimetres_unknown
    assert_nil @package.centimetres(:unknown)
  end

  def test_centimetres_alias_cm
    assert_equal @dimensions, @package.centimetres
    assert_equal @dimensions, @package.cm
  end

  def test_weight
    assert_equal @mass, @package.weight
    assert_instance_of ::Quantified::Mass, @package.weight
  end

  def test_weight_actual
    assert_equal @mass, @package.weight(type: :actual)
    assert_instance_of ::Quantified::Mass, @package.weight(type: :actual)
  end

  def test_weight_volumetric
    assert_equal ::Quantified::Mass.new(35, :grams), @package.weight(type: :volumetric)
  end

  def test_weight_dimensional
    assert_equal ::Quantified::Mass.new(35, :grams), @package.weight(type: :dimensional)
  end

  def test_weight_billable_max_weight_and_volumetric
    assert_equal ::Quantified::Mass.new(100, :grams), @package.weight(type: :billable)

    @package = Package.new(500, [1, 1, 1], @options)
    assert_equal ::Quantified::Mass.new(500, :grams), @package.weight(type: :billable)
  end

  def test_grams_value
    assert_equal 100, @package.grams
  end

  def test_grams_accepts_options_with_type
    assert_in_delta 35, @package.grams(type: :volumetric), 1
  end

  def test_grams_converts
    @package = Package.new(@weight, @dimensions, weight_units: :imperial)

    assert_in_delta 2834.9, @package.grams, 1
  end

  def test_grams_alias_g
    assert_equal @package.grams, @package.g
  end

  def test_ounces_value
    assert_equal 100, @imperial_package.ounces
  end

  def test_ounces_accepts_options_with_type
    assert_in_delta 20.2, @imperial_package.ounces(type: :volumetric), 1
  end

  def test_ounces_converts
    assert_in_delta 3.5, @package.ounces, 1
  end

  def test_ounces_alias_oz
    assert_equal @imperial_package.ounces, @imperial_package.oz
  end

  def test_pounds_value
    assert_equal 6.25, @imperial_package.pounds
  end

  def test_pounds_accepts_options_with_type
    assert_in_delta 0.07, @package.pounds(type: :volumetric), 0.01
  end

  def test_pounds_converts
    assert_in_delta 0.22, @package.pounds, 0.01
  end

  def test_pounds_alias_lb
    assert_equal @package.pounds, @package.lb
  end

  def test_pounds_alias_lbs
    assert_equal @package.pounds, @package.lbs
  end

  def test_kilograms_value
    assert_equal 0.1, @package.kilograms
  end

  def test_kilograms_accepts_options_with_type
    assert_equal 0.035, @package.kilograms(type: :volumetric)
  end

  def test_kilograms_converts
    assert_in_delta 2.8, @imperial_package.kilograms, 1
  end

  def test_kilograms_alias_kg
    assert_equal 0.1, @package.kg
  end

  def test_kilograms_alias_kgs
    assert_equal @package.kilograms, @package.kgs
  end

  def test_cents_from_nil
    assert_nil Package.cents_from(nil)
  end

  def test_cents_from_cents
    assert_equal @value, Package.cents_from(money)
  end

  def test_cents_from_float
    assert_equal 120, Package.cents_from(1.2)
  end

  def test_cents_from_string
    assert_equal 120, Package.cents_from("1.20")
  end

  def test_cents_from_int
    assert_equal 12, Package.cents_from(12)
  end

  def test_cents_from_nonsense
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
