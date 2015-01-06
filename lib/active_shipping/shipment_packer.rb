module ActiveShipping
  class ShipmentPacker
    class OverweightItem < StandardError
    end

    EXCESS_PACKAGE_QUANTITY_THRESHOLD = 10_000
    class ExcessPackageQuantity < StandardError; end

    # items           - array of hashes containing quantity, grams and price.
    #                   ex. [{:quantity => 2, :price => 1.0, :grams => 50}]
    # dimensions      - [5.0, 15.0, 30.0]
    # maximum_weight  - maximum weight in grams
    # currency        - ISO currency code
    def self.pack(items, dimensions, maximum_weight, currency)
      return [] if items.empty?
      packages = []

      # Naive in that it assumes weight is equally distributed across all items
      # Should raise early enough in most cases
      total_weight = 0
      items.map!(&:symbolize_keys).each do |item|
        total_weight += item[:quantity].to_i * item[:grams].to_i

        if item[:grams].to_i > maximum_weight
          raise OverweightItem, "The item with weight of #{item[:grams]}g is heavier than the allowable package weight of #{maximum_weight}g"
        end

        if total_weight > maximum_weight * EXCESS_PACKAGE_QUANTITY_THRESHOLD
          raise ExcessPackageQuantity, "Unable to pack more than #{EXCESS_PACKAGE_QUANTITY_THRESHOLD} packages"
        end
      end

      items = items.map(&:dup).sort_by! { |i| i[:grams].to_i }

      state = :package_empty
      while state != :packing_finished
        case state
        when :package_empty
          package_weight, package_value = 0, 0
          state = :filling_package
        when :filling_package
          items.each do |item|
            quantity = if item[:grams].to_i <= 0
              item[:quantity].to_i
            else
              # Grab the max amount of this item we can fit into this package
              # Or, if there are fewer than the max for this item, put
              # what is left into this package
              [(maximum_weight - package_weight) / item[:grams].to_i, item[:quantity].to_i].min
            end

            item_weight = quantity * item[:grams].to_i
            item_value = quantity * Package.cents_from(item[:price])

            package_weight += item_weight
            package_value += item_value

            item[:quantity] = item[:quantity].to_i - quantity
          end

          items.reject! { |i| i[:quantity].to_i == 0 }

          state = :package_full
        when :package_full
          packages << ActiveShipping::Package.new(package_weight, dimensions, :value => package_value, :currency => currency)
          state = items.any? ? :package_empty : :packing_finished
        end
      end

      packages
    end
  end
end
