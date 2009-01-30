module ActiveMerchant #:nodoc:
  module Shipping #:nodoc:
    class Package
      include Quantified
      
      GRAMS_IN_AN_OUNCE = 28.3495231
      OUNCES_IN_A_GRAM = 0.0352739619
      INCHES_IN_A_CM = 0.393700787
      CM_IN_AN_INCH = 2.54
      
      cattr_accessor :default_options
      attr_reader :options, :value, :currency
      
      # Package.new(100, [10, 20, 30], :units => :metric)
      def initialize(grams_or_ounces, dimensions, options = {})
        options = @@default_options.update(options) if @@default_options
        options.symbolize_keys!
        @options = options
        
        imperial = options[:units] == :imperial
        @unit_system = imperial ? :imperial : :metric
        dimensions = Array(dimensions)
        
        @ounces,@grams = nil
        if grams_or_ounces.nil?
          @grams = @ounces = 0
        elsif imperial
          @ounces = grams_or_ounces
        else
          @grams = grams_or_ounces
        end
        
        @inches,@centimetres = nil
        if dimensions.empty?
          @inches = @centimetres = [0,0,0]
        else
          process_dimensions(dimensions,imperial)
        end
        
        @value = Package.cents_from(options[:value])
        @currency = options[:currency] || (options[:value].currency if options[:value].respond_to?(:currency))
        @cylinder = (options[:cylinder] || options[:tube]) ? true : false
      end
  
      def cylinder?
        @cylinder
      end
      alias_method :tube?, :cylinder?
      
      def ounces(options={})
        case options[:type]
        when *[nil,:actual]: @ounces ||= grams(options) * OUNCES_IN_A_GRAM
        when *[:volumetric,:dimensional]: @volumetric_ounces ||= grams(options) * OUNCES_IN_A_GRAM
        when :billable: @billable_ounces ||= [ounces,ounces(:type => :volumetric)].max
        end
      end
      alias_method :oz, :ounces
  
      def grams(options={})
        case options[:type]
        when *[nil,:actual]: @grams ||= ounces(options) * GRAMS_IN_AN_OUNCE
        when *[:volumetric,:dimensional]: @volumetric_grams ||= centimetres(:box_volume) / 6.0
        when :billable: [grams,grams(:type => :volumetric)].max
        end
      end
      alias_method :g, :grams
  
      def pounds(options={})
        ounces(options) / 16.0
      end
      alias_method :lb, :pounds
      alias_method :lbs, :pounds
  
      def kilograms(options={})
        grams(options) / 1000.0
      end
      alias_method :kg, :kilograms
      alias_method :kgs, :kilograms
  
      def inches(measurement=nil)
        @inches ||= @centimetres.map {|cm| cm * INCHES_IN_A_CM}
        measurement.nil? ? @inches : measure(measurement, @inches)
      end
      alias_method :in, :inches
  
      def centimetres(measurement=nil)
        @centimetres ||= @inches.map {|inches| inches * CM_IN_AN_INCH}
        measurement.nil? ? @centimetres : measure(measurement, @centimetres)
      end
      alias_method :cm, :centimetres
      
      def mass
        if @unit_system == :metric
          Mass.new(@grams, :grams)
        else
          Mass.new(@ounces, :ounces)
        end
      end
      alias_method :weight, :mass
      
      def self.cents_from(money)
        return nil if money.nil?
        if money.respond_to?(:cents)
          return money.cents
        else
          return case money
            when Float
              (money * 100).to_i
            when String
              money =~ /\./ ? (money.to_f * 100).to_i : money.to_i
            else
              money.to_i
            end
        end
      end
  
      private
      
      def measure(measurement, ary)
        case measurement
        when Fixnum: ary[measurement]
        when *[:x,:max,:length,:long]: ary[2]
        when *[:y,:mid,:width,:wide]: ary[1]
        when *[:z,:min,:height,:depth,:high,:deep]: ary[0]
        when *[:girth,:around,:circumference]
          self.cylinder? ? (Math::PI * (ary[0] + ary[1]) / 2) : (2 * ary[0]) + (2 * ary[1])
        when :volume: self.cylinder? ? (Math::PI * (ary[0] + ary[1]) / 4)**2 * ary[2] : measure(:box_volume,ary)
        when :box_volume: ary[0] * ary[1] * ary[2]
        end
      end
      
      def process_dimensions(dimensions, imperial_units)
        units = imperial_units ? 'inches' : 'centimetres'
        self.instance_variable_set("@#{units}", dimensions.sort)
        units_array = self.instance_variable_get("@#{units}")
        # [1,2] => [1,1,2]
        # [5] => [5,5,5]
        # etc..
        2.downto(units_array.length) do |n|
          units_array.unshift(units_array[0])
        end
      end
  
    end
  end
end