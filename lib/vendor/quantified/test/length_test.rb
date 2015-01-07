require 'test_helper'
require 'quantified/length'

class LengthTest < Test::Unit::TestCase
  include Quantified
  Length.numeric_methods :metres, :centimetres, :inches, :feet

  def setup
    @length = Length.new(5, :feet)
  end

  def test_inspect
    assert_equal "#<Quantified::Length: 5 feet>", @length.inspect
  end

  def test_to_s
    assert_equal "5 feet", @length.to_s
  end

  def test_initialize_from_numeric
    assert_equal "5 feet", 5.feet.to_s
  end

  def test_equalities
    assert_equal 1.feet, (1.0).feet
    # == based on value
    assert_equal 6.feet, Length.new(2, :yards)
    # eql? based on value and unit
    assert !6.feet.eql?(Length.new(2, :yards))
    # equal? based on object identity
    assert !2.feet.equal?(2.feet)
  end

  def test_convert_mm_to_inches
    assert_equal 12, Length.new(304.8, :millimetres).to_inches
  end

  def test_convert_yards_to_feet
    assert 6.feet.eql?(Length.new(2, :yards).to_feet)
  end

  def test_convert_feet_to_yards
    assert Length.new(2, :yards).eql?(6.feet.to_yards)
  end

  def test_convert_yards_to_millimetres
    assert_in_epsilon Length.new(914.4, :millimetres).to_f, Length.new(1, :yards).to_millimetres.to_f
  end

  def test_convert_millimetres_to_yards
    assert_in_epsilon Length.new(1, :yards).to_f, Length.new(914.4, :millimetres).to_yards.to_f
  end

  def test_convert_metres_to_inches
    assert_in_epsilon 1.inches.to_f, (0.0254).metres.to_inches.to_f
  end

  def test_comparison_with_numeric
    assert 2.feet > 1
    assert 2.feet == 2
    assert 2.feet <= 2
    assert 2.feet < 3
  end

  def test_method_missing_to_i
    assert_equal 2, (2.4).feet.to_i
  end

  def test_method_missing_to_f
    assert_equal 2.4, (2.4).feet.to_f
  end

  def test_method_missing_minus
    assert_equal 2.feet, 5.feet - 3.feet
  end

  def test_numeric_methods_not_added_for_some_units
    assert_raises(NoMethodError) do
      2.yards
    end
    assert_raises(NoMethodError) do
      2.millimetres
    end
  end

  def test_systems
    assert_equal [:metric, :imperial], Length.systems
    assert_equal [:metres, :centimetres, :millimetres, :kilometres], Length.units(:metric)
    assert_equal [:inches, :feet, :yards, :miles], Length.units(:imperial)

    assert_equal :metric, 2.centimetres.system
    assert_equal :imperial, 2.feet.system
  end
end
