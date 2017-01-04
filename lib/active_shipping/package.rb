module ActiveShipping #:nodoc:
  class Package
    cattr_accessor :default_options
    attr_reader :options, :value, :currency

    # Package.new(100, [10, 20, 30], :units => :metric)
    # Package.new(Mass.new(100, :grams), [10, 20, 30].map {|m| Length.new(m, :centimetres)})
    # Package.new(100.grams, [10, 20, 30].map(&:centimetres))
    def initialize(grams_or_ounces, dimensions, options = {})
      options = @@default_options.update(options) if @@default_options
      options.symbolize_keys!
      @options = options

      @dimensions = [dimensions].flatten.reject(&:nil?)

      imperial = (options[:units] == :imperial) ||
                 ([grams_or_ounces, *dimensions].all? { |m| m.respond_to?(:unit) && m.unit.to_sym == :imperial })

      weight_imperial = dimensions_imperial = imperial if options.include?(:units)

      if options.include?(:weight_units)
        weight_imperial = (options[:weight_units] == :imperial) ||
                          (grams_or_ounces.respond_to?(:unit) && m.unit.to_sym == :imperial)
      end

      if options.include?(:dim_units)
        dimensions_imperial = (options[:dim_units] == :imperial) ||
                              (dimensions && dimensions.all? { |m| m.respond_to?(:unit) && m.unit.to_sym == :imperial })
      end

      @weight_unit_system = weight_imperial ? :imperial : :metric
      @dimensions_unit_system = dimensions_imperial ? :imperial : :metric

      @weight = attribute_from_metric_or_imperial(grams_or_ounces, Measured::Weight, @weight_unit_system, :grams, :ounces)

      if @dimensions.blank?
        zero_length = Measured::Length.new(0, (dimensions_imperial ? :inches : :centimetres))
        @dimensions = [zero_length] * 3
      else
        process_dimensions
      end

      @value = Package.cents_from(options[:value])
      @currency = options[:currency] || (options[:value].currency if options[:value].respond_to?(:currency))
      @cylinder = (options[:cylinder] || options[:tube]) ? true : false
      @gift = options[:gift] ? true : false
      @oversized = options[:oversized] ? true : false
      @unpackaged = options[:unpackaged] ? true : false
    end

    def unpackaged?
      @unpackaged
    end

    def oversized?
      @oversized
    end

    def cylinder?
      @cylinder
    end
    alias_method :tube?, :cylinder?

    def gift?
      @gift
    end

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

    def inches(measurement = nil)
      @inches ||= @dimensions.map { |m| m.convert_to(:in).value }
      measurement.nil? ? @inches : measure(measurement, @inches)
    end
    alias_method :in, :inches

    def centimetres(measurement = nil)
      @centimetres ||= @dimensions.map { |m| m.convert_to(:cm).value }
      measurement.nil? ? @centimetres : measure(measurement, @centimetres)
    end
    alias_method :cm, :centimetres

    def weight(options = {})
      case options[:type]
      when nil, :actual
        @weight
      when :volumetric, :dimensional
        @volumetric_weight ||= begin
          m = Measured::Weight.new((centimetres(:box_volume) / 6.0), :grams)
          @weight_unit_system == :imperial ? m.convert_to(:oz) : m
        end
      when :billable
        [weight, weight(:type => :volumetric)].max
      end
    end
    alias_method :mass, :weight

    def self.cents_from(money)
      return nil if money.nil?
      if money.respond_to?(:cents)
        return money.cents
      else
        case money
        when Float
          (money * 100).round
        when String
          money =~ /\./ ? (money.to_f * 100).round : money.to_i
        else
          money.to_i
        end
      end
    end

    private

    def attribute_from_metric_or_imperial(obj, klass, unit_system, metric_unit, imperial_unit)
      if obj.is_a?(klass)
        return obj
      else
        return klass.new(obj, (unit_system == :imperial ? imperial_unit : metric_unit))
      end
    end

    def measure(measurement, ary)
      case measurement
      when Integer then ary[measurement]
      when :x, :max, :length, :long then ary[2]
      when :y, :mid, :width, :wide then ary[1]
      when :z, :min, :height, :depth, :high, :deep then ary[0]
      when :girth, :around, :circumference
        self.cylinder? ? (Math::PI * (ary[0] + ary[1]) / 2) : (2 * ary[0]) + (2 * ary[1])
      when :volume then self.cylinder? ? (Math::PI * (ary[0] + ary[1]) / 4)**2 * ary[2] : measure(:box_volume, ary)
      when :box_volume then ary[0] * ary[1] * ary[2]
      end
    end

    def process_dimensions
      @dimensions = @dimensions.map do |l|
        attribute_from_metric_or_imperial(l, Measured::Length, @dimensions_unit_system, :centimetres, :inches)
      end.sort
      # [1,2] => [1,1,2]
      # [5] => [5,5,5]
      # etc..
      2.downto(@dimensions.length) do |_n|
        @dimensions.unshift(@dimensions[0])
      end
    end
  end
end
