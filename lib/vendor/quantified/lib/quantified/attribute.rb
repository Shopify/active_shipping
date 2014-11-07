module Quantified
  class Attribute
    include Comparable

    attr_reader :amount, :unit

    def initialize(amount, unit)
      raise ArgumentError, "amount must be a Numeric" unless amount.is_a?(Numeric)
      @amount, @unit = amount, unit.to_sym
    end

    def to_s
      "#{amount} #{unit}"
    end

    def inspect
      "#<#{self.class.name}: #{amount} #{unit}>"
    end

    def ==(other)
      (BigDecimal.new(amount.to_s) == BigDecimal.new(other.amount.to_s) && unit == other.unit) || BigDecimal.new(self.class.convert(amount, unit, other.unit).to_s) == BigDecimal.new(other.amount.to_s)
    rescue NoMethodError
      amount == other
    end

    def eql?(other)
      self.class == other.class && BigDecimal.new(amount.to_s) == BigDecimal.new(other.amount.to_s) && unit == other.unit
    end

    def <=>(other)
      if self.class == other.class
        self.class.convert(amount, unit, other.unit) <=> other.amount
      else
        amount <=> other
      end
    end

    def system
      self.class.units_to_systems[unit]
    end

    def coerce(other)
      [other, amount]
    end

    def method_missing(meth, *args)
      if args.size == 1 && self.class == (other = args.first).class
        other_amount_in_self_units = self.class.convert(other.amount, other.unit, unit)
        self.class.new(amount.send(meth, other_amount_in_self_units), unit)
      else
        amount.send(meth, *args)
      end
    end

    def self.conversion_rate(from, to)
      return nil unless conversions[from] and conversions[to]
      conversions[from][to] ||=
      (1.0 / conversions[to][from] if conversions[to][from]) || begin
        shared_conversions = conversions[from].keys & conversions[to].keys
        if shared_conversions.any?
          primitive = shared_conversions.first
          conversions[from][primitive] * (1.0 / conversions[to][primitive])
        else
          conversions[from].each do |conversion_unit, multiple|
            if conversions[to].include?(conversion_unit)
              return multiple * conversion_rate(conversion) * (1.0 / conversions[to][conversion_unit])
            end
          end
          from_primitive = (conversions[from].keys & primitives).first
          to_primitive = (conversions[to].keys & primitives).first
          if from_primitive_to_primitive_multiple = conversion_rate(from_primitive, to_primitive)
            return conversions[from][from_primitive] * from_primitive_to_primitive_multiple * (1.0 / conversions[to][to_primitive])
          end
          raise StandardError, "No conversion path from #{from} to #{to}"
        end
      end
    end

    def self.units(system = nil)
      if system
        systems_to_units[system.to_sym].dup
      else
        primitives | conversions.keys
      end
    end

    def self.non_primitives
      conversions.keys
    end

    def self.systems
      systems_to_units.keys
    end

    def self.add_numeric_methods?
      add_numeric_methods
    end

    def self.numeric_methods(*args)
      args.each do |arg|
        add_numeric_method_for(arg.to_sym)
      end
    end

    protected

    class << self
      def primitives;              @primitives ||= [];             end
      def add_numeric_methods;     @add_numeric_methods ||= false; end
      attr_writer :add_numeric_methods
      def conversions;             @conversions ||= {};            end
      attr_reader :current_system
      attr_writer :current_system
      def systems_to_units;        @systems_to_units ||= {};       end
      def units_to_systems;        @units_to_systems ||= {};       end
    end

    def self.system(system_name, &block)
      old_system = current_system
      self.current_system = system_name.to_sym
      yield
      self.current_system = old_system
    end

    def self.primitive(sym, options = {})
      unit_sym = (options[:plural] || sym.to_s.pluralize).to_sym
      primitives << unit_sym
      add_to_system(unit_sym)
      add_methods_for(unit_sym, options)
    end

    def self.add_to_system(unit_sym)
      if current_system
        units_to_systems[unit_sym] ||= begin
          sys_ary = systems_to_units[current_system] ||= []
          sys_ary << unit_sym
          current_system
        end
      end
    end

    def self.one(sym, options = {})
      unit_sym = (options[:plural] || sym.to_s.pluralize).to_sym
      add_to_system(unit_sym)
      register_unit(unit_sym, options[:is].unit, options[:is].amount)
      add_methods_for(unit_sym, options)
    end

    def self.register_unit(multiple_unit, other_unit, multiple)
      multiple_unit, other_unit = multiple_unit.to_sym, other_unit.to_sym
      conversions[multiple_unit] ||= {}
      conversions[other_unit] ||= {}

      if primitives.include?(multiple_unit) || primitives.include?(other_unit)
        add_conversion(multiple_unit, other_unit, multiple)
      else
        [multiple_unit, other_unit].each do |this_unit|
          conversions[this_unit].each do |this_other_unit, this_multiple|
            if primitives.include?(this_other_unit)
              add_conversion(multiple_unit, this_other_unit, multiple * this_multiple)
            end
          end
        end
      end
    end

    def self.add_conversion(multiple_unit, other_unit, multiple)
      conversions[multiple_unit] ||= {}
      conversions[multiple_unit][other_unit] = multiple
      conversions[other_unit] ||= {}
      conversions[other_unit][multiple_unit] = (1.0 / multiple)
    end

    def self.convert(amount, from, to)
      from, to = from.to_sym, to.to_sym
      amount * conversion_rate(from, to)
    end

    def self.add_methods_for(sym, options = {})
      add_conversion_method_for(sym, options)
      add_numeric_method = if options.has_key?(:add_numeric_methods)
        options[:add_numeric_methods]
      else
        add_numeric_methods
      end
      add_numeric_method_for(sym.to_s, options) if add_numeric_method
    end

    def self.add_conversion_method_for(sym, options = {})
      unit_name = sym.to_s
      class_eval do
        define_method("to_#{unit_name}") do
          return self if unit_name == unit.to_s
          self.class.new(self.class.convert(amount, unit, unit_name), unit_name)
        end
        alias_method("in_#{unit_name}", "to_#{unit_name}")
      end
    end

    def self.add_numeric_method_for(unit_name, options = {})
      unit_name = unit_name.to_sym
      raise ArgumentError, "#{unit_name.inspect} is not a unit in #{name}" unless units.include?(unit_name)
      klass = self
      Numeric.class_eval do
        define_method(unit_name) do
          klass.new(self, unit_name.to_sym)
        end
      end
    end
  end
end
