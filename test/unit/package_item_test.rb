require 'test_helper'

class PackageItemTest < ActiveSupport::TestCase
  setup do
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
    @mass = Measured::Weight.new(@weight, :grams)
  end

  test "#initialize with all attributes" do
    assert_equal @name, @item.name
    assert_equal @options, @item.options
    assert_equal @hs_code, @item.hs_code
    assert_equal @sku, @item.sku
    assert_equal @value, @item.value
    assert_equal @quantity, @item.quantity
  end

  test "#initialize assumes symbol keys" do
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

  test "#initialize with a negative quantity" do
    assert_equal 1, PackageItem.new(@name, @weight, @value, -1).quantity
    assert_equal 1, PackageItem.new(@name, @weight, @value, 0).quantity
  end

  test "#initialize weight mass object" do
    @item = PackageItem.new(@name, @mass, @value, @quantity, @options)
    assert_equal @mass, @item.weight
  end

  test "#initialize weight default metric" do
    assert_equal @weight, @item.grams
    refute_equal @weight, @item.ounces
  end

  test "#initialize weight accepts imperial" do
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :imperial))

    assert_equal @weight, @item.ounces
    refute_equal @weight, @item.grams
  end

  test "#initialize_weight accepts metric" do
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :metric))

    assert_equal @weight, @item.grams
    refute_equal @weight, @item.ounces
  end

  test "#initialize weight does not accept strings" do
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: "imperial"))

    assert_equal @weight, @item.grams
    refute_equal @weight, @item.ounces
  end

  test "#initialize value from cents" do
    @item = PackageItem.new(@name, @weight, "1.23", @quantity, @options)

    assert_equal 123, @item.value
  end

  test "#weight default lookup" do
    assert_equal @mass, @item.weight
    assert_instance_of Measured::Weight, @item.weight
  end

  test "#weight type: actual" do
    assert_equal @mass, @item.weight(type: :actual)
    assert_instance_of Measured::Weight, @item.weight(type: :actual)
  end

  test "#weight type: volumetric" do
    begin
      assert_equal :todo, @item.weight(type: :volumetric)
      assert_instance_of Measured::Weight, @item.weight(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  test "#weight type: dimensional" do
    begin
      assert_equal :todo, @item.weight(type: :dimensional)
      assert_instance_of Measured::Weight, @item.weight(type: :dimensional)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  test "#weight type: billable is the max of weight and volumetric" do
    begin
      assert_equal :todo, @item.weight(type: :billable)
      assert_instance_of Measured::Weight, @item.weight(type: :billable)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  test "#grams is the value" do
    assert_equal 100, @item.grams
  end

  test "#grams accepts options with type" do
    begin
      assert_equal :todo, @item.grams(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  test "#grams converts to another unit" do
    @item = PackageItem.new(@name, 100, @value, @quantity, @options.merge(units: :imperial))

    assert_in_delta 2834.9, @item.grams, 0.1
  end

  test "#grams aliases to g" do
    assert_equal @item.grams, @item.g
  end

  test "#ounces is the value" do
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :imperial))

    assert_equal 100, @item.ounces
  end

  test "#ounces accepts options with type" do
    begin
      assert_equal :todo, @item.ounces(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue NoMethodError
      skip "This code path is broken"
    end
  end

  test "#ounces converts to another unit" do
    @item = PackageItem.new(@name, @weight, @value, @quantity, @options.merge(units: :metric))

    assert_in_delta 3.5, @item.ounces, 0.1
  end

  test "#ounces aliases to oz" do
    assert_equal @item.ounces, @item.oz
  end

  test "#pounds is the value" do
    @item = PackageItem.new(@name, 32, @value, @quantity, @options.merge(units: :imperial))

    assert_equal 2, @item.pounds
  end

  test "#pounds accepts options with type" do
    begin
      assert_equal :todo, @item.pounds(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue
      skip "This code path is broken"
    end
  end

  test "#pounds converts to another unit" do
    @item = PackageItem.new(@name, 1000, @value, @quantity, @options.merge(units: :metric))

    assert_in_delta 2.2, @item.pounds, 0.1
  end

  test "#pounds aliases to lb" do
    assert_equal @item.pounds, @item.lb
  end

  test "#pounds aliases to lbs" do
    assert_equal @item.pounds, @item.lbs
  end

  test "#kilograms is the value" do
    @item = PackageItem.new(@name, 1000, @value, @quantity, @options.merge(units: :metric))

    assert_equal 1, @item.kilograms
  end

  test "#kilograms accepts options with type" do
    begin
      assert_equal :todo, @item.kilograms(type: :volumetric)
      flunk "This code path is broken but passed unexpectedly"
    rescue
      skip "This code path is broken"
    end
  end

  test "#kilograms converts to another unit" do
    @item = PackageItem.new(@name, 1000, @value, @quantity, @options.merge(units: :imperial))

    assert_in_delta 28.3, @item.kilograms, 0.1
  end

  test "#kilograms aliases to kg" do
    assert_equal @item.kilograms, @item.kg
  end

  test "#kilograms aliases to kgs" do
    assert_equal @item.kilograms, @item.kgs
  end
end
