module ActiveShipping
  class ShipmentPacker
    class OverweightItem < StandardError
    end

    EXCESS_PACKAGE_QUANTITY_THRESHOLD = 10_000
    class ExcessPackageQuantity < StandardError; end

    # items           - array of hashes containing quantity, grams and price.
    #                   ex. `[{:quantity => 2, :price => 1.0, :grams => 50}]`
    # dimensions      - `[5.0, 15.0, 30.0]`
    # maximum_weight  - maximum weight in grams
    # currency        - ISO currency code

    class << self
      def pack(items, dimensions, maximum_weight, currency)
        return [] if items.empty?
        packages = []
        items.map!(&:symbolize_keys)

        # Naive in that it assumes weight is equally distributed across all items
        # Should raise early enough in most cases
        validate_total_weight(items, maximum_weight)
        items_to_pack = items.map(&:dup).sort_by! { |i| i[:grams].to_i }

        state = :package_empty
        while state != :packing_finished
          case state
          when :package_empty
            package_weight, package_value = 0, 0
            state = :filling_package
          when :filling_package
            validate_package_quantity(packages.count)

            items_to_pack.each do |item|
              quantity = determine_fillable_quantity_for_package(item, maximum_weight, package_weight)
              package_weight += item_weight(quantity, item[:grams])
              package_value += item_value(quantity, item[:price])
              item[:quantity] = item[:quantity].to_i - quantity
            end

            items_to_pack.reject! { |i| i[:quantity].to_i == 0 }
            state = :package_full
          when :package_full
            packages << ActiveShipping::Package.new(package_weight, dimensions, value: package_value, currency: currency)
            state = items_to_pack.any? ? :package_empty : :packing_finished
          end
        end

        packages
      end

      private

      def validate_total_weight(items, maximum_weight)
        total_weight = 0
        items.each do |item|
          total_weight += item[:quantity].to_i * item[:grams].to_i

          if overweight_item?(item[:grams], maximum_weight)
            raise OverweightItem, "The item with weight of #{item[:grams]}g is heavier than the allowable package weight of #{maximum_weight}g"
          end

          raise_excess_quantity_error if maybe_excess_package_quantity?(total_weight, maximum_weight)
        end
      end

      def validate_package_quantity(number_of_packages)
        raise_excess_quantity_error if number_of_packages >= EXCESS_PACKAGE_QUANTITY_THRESHOLD
      end

      def raise_excess_quantity_error
        raise ExcessPackageQuantity, "Unable to pack more than #{EXCESS_PACKAGE_QUANTITY_THRESHOLD} packages"
      end

      def overweight_item?(grams, maximum_weight)
        grams.to_i > maximum_weight
      end

      def maybe_excess_package_quantity?(total_weight, maximum_weight)
        total_weight > (maximum_weight * EXCESS_PACKAGE_QUANTITY_THRESHOLD)
      end

      def determine_fillable_quantity_for_package(item, maximum_weight, package_weight)
        item_grams = item[:grams].to_i
        item_quantity = item[:quantity].to_i

        if item_grams <= 0
          item_quantity
        else
          # Grab the max amount of this item we can fit into this package
          # Or, if there are fewer than the max for this item, put
          # what is left into this package
          available_grams = (maximum_weight - package_weight).to_i
          [available_grams / item_grams, item_quantity].min
        end
      end

      def item_weight(quantity, grams)
        quantity * grams.to_i
      end

      def item_value(quantity, price)
        quantity * Package.cents_from(price)
      end
    end
  end
end
