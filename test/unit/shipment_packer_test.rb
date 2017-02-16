require 'test_helper'

class ShipmentPackerTest < ActiveSupport::TestCase
  def setup
    @dimensions = [5.1, 15.2, 30.5]
  end

  test "pack divide order into a single package" do
    items = [{ grams: 1, quantity: 1, price: 1.0 }]

    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')
    assert_equal 1, packages.size

    package = packages.first
    assert_equal Measured::Weight(1, :g), package.weight
  end

  test "divide order with multiple lines into a single package" do
    items = [{ grams: 1, quantity: 2, price: 1.0 }]

    packages = ShipmentPacker.pack(items, @dimensions, 2, 'USD')
    assert_equal 1, packages.size

    package = packages.first
    assert_equal Measured::Weight(2, :g), package.weight
  end

  test "divide order with single line into two packages" do
    items = [{ grams: 1, quantity: 2, price: 1.0 }]

    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')
    assert_equal 2, packages.size

    packages.each do |package|
      assert_equal Measured::Weight(1, :g), package.weight
    end
  end

  test "divide order with single line into two packages max weight as float" do
    max_weight = 68038.8555

    items = [{ grams: 45359, quantity: 2, price: 1.0 }]

    packages = ShipmentPacker.pack(items, @dimensions, max_weight, 'USD')
    assert_equal 2, packages.size

    packages.each do |package|
      assert_equal Measured::Weight(45359, :g), package.weight
    end
  end

  test "divide order with multiple lines into two packages" do
    items = [
      { grams: 1, quantity: 1, price: 1.0 },
      { grams: 1, quantity: 1, price: 1.0 }
    ]

    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')
    assert_equal 2, packages.size

    packages.each do |package|
      assert_equal Measured::Weight(1, :g), package.weight
    end
  end

  test "divide order into two packages mixing line items" do
    items = [
      { grams: 1, quantity: 1, price: 1.0 },
      { grams: 1, quantity: 1, price: 1.0 },
      { grams: 1, quantity: 1, price: 1.0 }
    ]

    packages = ShipmentPacker.pack(items, @dimensions, 2, 'USD')
    assert_equal 2, packages.size

    assert_equal Measured::Weight(2, :g), packages[0].weight
    assert_equal Measured::Weight(1, :g), packages[1].weight
  end

  test "raise overweight exception when a single item exceeds the maximum weight of a package" do
    assert_raises(ShipmentPacker::OverweightItem) do
      items = [{ grams: 2, quantity: 1, price: 1.0 }]
      ShipmentPacker.pack(items, @dimensions, 1, 'USD')
    end
  end

  test "raise over weight exceptions before over package limit exceptions" do
    assert_raises(ShipmentPacker::OverweightItem) do
      items = [{ grams: 5, quantity: ShipmentPacker::EXCESS_PACKAGE_QUANTITY_THRESHOLD + 1, price: 1.0 }]
      ShipmentPacker.pack(items, @dimensions, 4, 'USD')
    end
  end

  test "returns an empty list when no items provided" do
    assert_equal [], ShipmentPacker.pack([], @dimensions, 1, 'USD')
  end

  test "add summarized prices for all items and currency to package" do
    items = [
      { grams: 1, quantity: 3, price: 1.0 },
      { grams: 2, quantity: 1, price: 2.0 }
    ]
    packages = ShipmentPacker.pack(items, @dimensions, 5, 'USD')
    assert_equal 1, packages.size
    assert_equal 500, packages.first.value
    assert_equal 'USD', packages.first.currency
  end

  test "divide items and prices accordingly when splitting into two packages" do
    items = [
      { grams: 1, quantity: 1, price: 1.0 },
      { grams: 1, quantity: 1, price: 1.0 },
      { grams: 1, quantity: 1, price: 1.0 }
    ]

    packages = ShipmentPacker.pack(items, @dimensions, 2, 'USD')
    assert_equal 2, packages.size

    assert_equal 200, packages[0].value
    assert_equal 100, packages[1].value
    assert_equal 'USD', packages[0].currency
    assert_equal 'USD', packages[1].currency
  end

  test "symbolize item keys" do
    string_key_items          = [{ 'grams' => 1, 'quantity' => 1, 'price' => 1.0 }]
    indifferent_access_items  = [{ 'grams' => 1, 'quantity' => 1, 'price' => 1.0 }.with_indifferent_access]

    [string_key_items, indifferent_access_items].each do |items|
      packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')
      assert_equal 1, packages.size

      package = packages.first
      assert_equal Measured::Weight(1, :g), package.weight
      assert_equal 100, package.value
    end
  end

  test "cast quantity and grams to int" do
    items = [{ grams: '1', quantity: '1', price: '1.0' }]

    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')

    package = packages.first
    assert_equal Measured::Weight(1, :g), package.weight
    assert_equal 100, package.value
  end

  test "excess packages raised over threshold before packing begins" do
    ActiveShipping::Package.expects(:new).never
    items = [{ grams: 1, quantity: ShipmentPacker::EXCESS_PACKAGE_QUANTITY_THRESHOLD + 1, price: 1.0 }]

    assert_raises(ShipmentPacker::ExcessPackageQuantity) do
      ShipmentPacker.pack(items, @dimensions, 1, 'USD')
    end
  end

  test "excess packages not raised at threshold" do
    items = [{ grams: 1, quantity: ShipmentPacker::EXCESS_PACKAGE_QUANTITY_THRESHOLD, price: 1.0 }]
    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')

    assert_predicate packages, :present?
  end

  test "excess packages not raised below threshold" do
    items = [{ grams: 1, quantity: ShipmentPacker::EXCESS_PACKAGE_QUANTITY_THRESHOLD - 1, price: 1.0 }]
    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')

    assert_predicate packages, :present?
  end

  test "excess packages with slightly larger max weight than item weight" do
    max_weight = 750
    items = [{ grams: 500, quantity: ShipmentPacker::EXCESS_PACKAGE_QUANTITY_THRESHOLD + 1, price: 1.0 }]

    assert_raises(ShipmentPacker::ExcessPackageQuantity) do
      ShipmentPacker.pack(items, @dimensions, max_weight, 'USD')
    end
  end

  test "lots of zero weight items" do
    items = [{ grams: 0, quantity: 1_000_000, price: 1.0 }]
    packages = ShipmentPacker.pack(items, @dimensions, 1, 'USD')

    assert_equal 1, packages.size
    assert_equal 0, packages[0].grams
    assert_equal 100_000_000, packages[0].value
  end

  test "dont destroy input items" do
    items = [{ grams: 1, quantity: 5, price: 1.0 }]

    packages = ShipmentPacker.pack(items, @dimensions, 10, 'USD')

    assert_equal 1, items.size
    assert_equal 1, packages.size
  end

  test "dont modify input item quantities" do
    items = [{ grams: 1, quantity: 5, price: 1.0 }]

    ShipmentPacker.pack(items, @dimensions, 10, 'USD')
    assert_equal 5, items.first[:quantity]
  end

  test "items with negative weight" do
    items = [{ grams: -1, quantity: 5, price: 1.0 }]

    ShipmentPacker.pack(items, @dimensions, 10, 'USD')
    assert_equal 5, items.first[:quantity]
  end
end
