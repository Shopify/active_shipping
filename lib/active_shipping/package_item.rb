module ActiveShipping #:nodoc:
  class PackageItem
    attr_reader :sku, :hs_code, :value, :name, :weight, :quantity, :options

    def initialize(name, grams_or_ounces, value, quantity, options = {})
      @name = name

      imperial = (options[:units] == :imperial) ||
                 (grams_or_ounces.respond_to?(:unit) && m.unit.to_sym == :imperial)

      @unit_system = imperial ? :imperial : :metric

      @weight = attribute_from_metric_or_imperial(grams_or_ounces, Measured::Weight, :grams, :ounces)

      @value = Package.cents_from(value)
      @quantity = quantity > 0 ? quantity : 1

      @sku = options[:sku]
      @hs_code = options[:hs_code]
      @options = options
    end

    def weight(options = {})
      case options[:type]
      when nil, :actual
        @weight
      when :volumetric, :dimensional
        @volumetric_weight ||= begin
          m = Measured::Weight.new((centimetres(:box_volume) / 6.0), :grams)
          @unit_system == :imperial ? m.in_ounces : m
        end
      when :billable
        [weight, weight(:type => :volumetric)].max
      end
    end
    alias_method :mass, :weight

    def ounces(options = {})
      weight(options).convert_to(:oz).value
    end
    alias_method :oz, :ounces

    def grams(options = {})
      weight(options).convert_to(:g).value
    end
    alias_method :g, :grams

    def pounds(options = {})
      weight(options).convert_to(:lb).value
    end
    alias_method :lb, :pounds
    alias_method :lbs, :pounds

    def kilograms(options = {})
      weight(options).convert_to(:kg).value
    end
    alias_method :kg, :kilograms
    alias_method :kgs, :kilograms

    private

    def attribute_from_metric_or_imperial(obj, klass, metric_unit, imperial_unit)
      if obj.is_a?(klass)
        return value
      else
        return klass.new(obj, (@unit_system == :imperial ? imperial_unit : metric_unit))
      end
    end
  end
end
