module ActiveMerchant
  module Shipping
    class ShipmentPacker
      class OverweightItem < StandardError
      end

      # items           - array of hashes containing quantity, grams and price.
      #                   ex. [{:quantity => 2, :price => 1.0, :grams => 50}]
      # dimensions      - [5.0, 15.0, 30.0]
      # maximum_weight  - maximum weight in grams
      # currency        - ISO currency code
      def self.pack(items, dimensions, maximum_weight, currency)
        items = items.map(&:symbolize_keys).map { |item| [item] * item[:quantity].to_i }.flatten
        packages = []
        state = :package_empty

        while state != :packing_finished
          case state
          when :package_empty
            package_weight, package_value = 0, 0
            state = :filling_package
          when :filling_package
            item = items.shift
            item_weight, item_price = item[:grams].to_i, Package.cents_from(item[:price])

            if item_weight > maximum_weight
              raise OverweightItem, "The item with weight of #{item_weight}g is heavier than the allowable package weight of #{maximum_weight}g"
            end

            if (package_weight + item_weight) <= maximum_weight
              package_weight += item_weight
              package_value  += item_price
              state = :package_full if items.empty?
            else
              items.unshift(item)
              state = :package_full
            end
          when :package_full
            packages << ActiveMerchant::Shipping::Package.new(package_weight, dimensions, :value => package_value, :currency => currency)
            state = items.any? ? :package_empty : :packing_finished
          end
        end

        packages
      end
    end
  end
end
