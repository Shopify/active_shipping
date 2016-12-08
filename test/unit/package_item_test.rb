require 'test_helper'

class PackageItemTest < ActiveSupport::TestCase
  def setup
    @name = "Fancy Pants"
    @weight = 100
    @value = 1299
    @quantity = 3
    @sku = "1234567890"
    @hs_code = "1234.56.78"
    @options = {
      units: :metric,
      sku: @sku,
      hs_code: @hs_code,
      type: :actual,
    }

    @item = PackageItem.new(@name, @weight, @value, @quantity, @options)
    @mass = ::Quantified::Mass.new(@weight, :grams)
  end

  def test_initialize_with_all_attributes
    assert_equal @name, @item.name
    assert_equal @options, @item.options
    assert_equal @hs_code, @item.hs_code
    assert_equal @sku, @item.sku
    assert_equal @value, @item.value
    assert_equal @quantity, @item.quantity
  end

  def test_initialize_assumes_symbol_keys
    options = {
      "units" => :imperial,
      "sku" => @sku,
      "hs_code" => @hs_code,
    }
    @item = PackageItem.new(@name, @weight, @value, @quantity, options)

    assert_nil @item.hs_code
    assert_nil @item.sku
    refute_equal @weight, @item.ounces
    assert_equal @weight, @item.grams
  end

  def test_initialize_negative_quantity
    assert_equal 1, PackageItem.new(@name, @weight, @value, -1).quantity
    assert_equal 1, PackageItem.new(@name, @weight, @value, 0).quantity
  end

  def test_initialize_weight_mass_object
    begin
      @item = PackageItem.new(@name, @mass, @value, @quantity, @options)
      assert_equal @mass, @item.weight
      flunk "This code path is broken but passed unexpectedly"
    rescue NameError
      skip "This code path is broken"
    end
  end

  def test_initialize_weight_default_metric
    assert_equal @weight, @item.grams
    refute_equal @weight, @item.ounces
  end

  def test_initialize_weight_accepts_imperial
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :imperial))

    assert_equal @weight, @item.ounces
    refute_equal @weight, @item.grams
  end

  def test_initialize_weight_accepts_metric
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :metric))

    assert_equal @weight, @item.grams
    refute_equal @weight, @item.ounces
  end

  def test_initialize_weight_does_not_accept_strings
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: "imperial"))

    assert_equal @weight, @item.grams
    refute_equal @weight, @item.ounces
  end

  def test_initialize_value_from_cents
    @item = PackageItem.new(@name, @weight, "1.23", @quantity, @options)

    assert_equal 123, @item.value
  end

  def test_weight
    assert_equal @mass, @item.weight
    assert_instance_of ::Quantified::Mass, @item.weight
  end

  def test_weight_actual
    assert_equal @mass, @item.weight(type: :actual)
    assert_instance_of ::Quantified::Mass, @item.weight(type: :actual)
  end

  def test_weight_volumetric
    begin
      assert_equal :todo, @item.weight(type: :volumetric)
      assert_instance_of ::Quantified::Mass, @item.weight(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  def test_weight_dimensional
    begin
      assert_equal :todo, @item.weight(type: :dimensional)
      assert_instance_of ::Quantified::Mass, @item.weight(type: :dimensional)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  def test_weight_billable_max_weight_and_volumetric
    begin
      assert_equal :todo, @item.weight(type: :billable)
      assert_instance_of ::Quantified::Mass, @item.weight(type: :billable)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  def test_grams_value
    assert_equal 100, @item.grams
  end

  def test_grams_accepts_options_with_type
    begin
      assert_equal :todo, @item.grams(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  def test_grams_converts
    @item = PackageItem.new(@name, 100, @value, @quantity, @options.merge(units: :imperial))

    assert_in_delta 2834.9, @item.grams, 0.1
  end

  def test_grams_alias_g
    assert_equal @item.grams, @item.g
  end

  def test_ounces_value
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :imperial))

    assert_equal 100, @item.ounces
  end

  def test_ounces_accepts_options_with_type
    begin
      assert_equal :todo, @item.ounces(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  def test_ounces_converts
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :metric))

    assert_in_delta 3.5, @item.ounces, 0.1
  end

  def test_ounces_alias_oz
    assert_equal @item.ounces, @item.oz
  end

  def test_pounds_value
    @item = PackageItem.new(@name, 32, @value, @quantity, @options.merge(units: :imperial))

    assert_equal 2, @item.pounds
  end

  def test_pounds_accepts_options_with_type
    begin
      assert_equal :todo, @item.pounds(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue
      skip "This code path is broken"
    end
  end

  def test_pounds_converts
    @item = PackageItem.new(@name, 1000, @value, @quantity, @options.merge(units: :metric))

    assert_in_delta 2.2, @item.pounds, 0.1
  end

  def test_pounds_alias_lb
    assert_equal @item.pounds, @item.lb
  end

  def test_pounds_alias_lbs
    assert_equal @item.pounds, @item.lbs
  end

  def test_kilograms_value
    @item = PackageItem.new(@name, 1000, @value, @quantity, @options.merge(units: :metric))

    assert_equal 1, @item.kilograms
  end

  def test_kilograms_accepts_options_with_type
    begin
      assert_equal :todo, @item.kilograms(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue
      skip "This code path is broken"
    end
  end

  def test_kilograms_converts
    @item = PackageItem.new(@name, 1000, @value, @quantity, @options.merge(units: :imperial))

    assert_in_delta 28.3, @item.kilograms, 0.1
  end

  def test_kilograms_alias_kg
    assert_equal @item.kilograms, @item.kg
  end

  def test_kilograms_alias_kgs
    assert_equal @item.kilograms, @item.kgs
  end
end
