require 'test_helper'
require 'quantified/mass'

class MassTest < Test::Unit::TestCase
  include Quantified
  Mass.numeric_methods :grams, :kilograms, :ounces, :pounds
  
  def setup
    @mass = Mass.new(5, :pounds)
  end

  def test_inspect
    assert_equal "#<Quantified::Mass: 5 pounds>", @mass.inspect
  end

  def test_to_s
    assert_equal "5 pounds", @mass.to_s
  end
  
  def test_initialize_from_numeric
    assert_equal "5 pounds", 5.pounds.to_s
  end
  
  def test_equalities
    assert_equal 1.pounds, (1.0).pounds
    # == based on value
    assert_equal 4000.pounds, Mass.new(2, :short_tons)
    # eql? based on value and unit
    assert !4000.pounds.eql?(Mass.new(2, :short_tons))
    # equal? based on object identity
    assert !2.pounds.equal?(2.pounds)
  end
  
  def test_convert_short_tons_to_pounds
    assert 4000.pounds.eql?(Mass.new(2, :short_tons).to_pounds)
  end
  
  def test_convert_pounds_to_short_tons
    assert Mass.new(2, :short_tons).eql?(4000.pounds.to_short_tons)
  end
  
  def test_convert_short_tons_to_milligrams
    assert Mass.new(907_184_740, :milligrams).eql?(Mass.new(1, :short_tons).to_milligrams)
  end
  
  def test_convert_milligrams_to_short_tons
    assert Mass.new(1, :short_tons).eql?(Mass.new(907_184_740, :milligrams).to_short_tons)
  end
  
  def test_convert_grams_to_ounces
    assert 1.ounces.eql?((28.349523125).grams.to_ounces)
    assert 1.ounces.eql?((28.349523125).grams.in_ounces)
  end
  
  def test_comparison_with_numeric
    assert 2.pounds > 1
    assert 2.pounds == 2
    assert 2.pounds <= 2
    assert 2.pounds < 3
  end
  
  def test_method_missing_to_i
    assert_equal 2, (2.4).pounds.to_i
  end
  
  def test_method_missing_to_f
    assert_equal 2.4, (2.4).pounds.to_f
  end
  
  def test_method_missing_minus
    assert_equal 2.pounds, 5.pounds - 3.pounds
  end
  
  def test_numeric_methods_not_added_for_some_units
    assert_raises NoMethodError do
      2.short_tons
    end
    assert_raises NoMethodError do
      2.milligrams
    end
  end
  
  def test_systems
    assert_equal [:metric, :imperial], Mass.systems
    assert_equal [:grams, :milligrams, :kilograms], Mass.units(:metric)
    assert_equal [:ounces, :pounds, :stones, :short_tons], Mass.units(:imperial)
  end
end