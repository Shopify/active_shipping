module ActiveShipping

  # Class representing a shipping option with estimated price.
  #
  # @!attribute origin
  #   The origin of the shipment
  #   @return [ActiveShipping::Location]
  #
  # @!attribute desination
  #   The desination of the shipment
  #   @return [ActiveShipping::Location]
  #
  # @!attribute package_rates
  #   A list of rates for all the packages in the shipment.
  #   @return [Array<{:rate => Integer, :package => ActiveShipping::Package}>]
  #
  # @!attribute carrier
  #   The name of the carrier (i.e. , e.g. 'USPS', 'FedEx')
  #   @return [String]
  #   @see ActiveShipping::Carrier.name
  #
  # @!attribute service_name
  #   The name of the shipping service (e.g. `"First Class Ground"`)
  #   @return [String]
  #
  # @!attribute service_code
  #   The code of the shipping service
  #   @return [String]
  #
  # @!attribute shipping_date
  #   The date on which the shipment will be expected. Normally, this means that the
  #   delivery date range can only pe prmoised if the shipment is handed over on or
  #   before this date.
  #   @return [Date]
  #
  # @!attribute delivery_date
  #   The date on which the shipment will be delivered. This is usually only availablee
  #   for express shipments; in order cases a {#delivery_range} is given instead.
  #   @return [Date]
  #
  # @!attribute delivery_range
  #   The minimum and maximum date of when the shipment is expected to be delivered.
  #   @return [Array<Date>]
  #
  # @!attribute currency
  #   ISO4217 currency code of the quoted rate estimates, e.g. `CAD`, `EUR`, or `USD`.
  #   @return [String]
  #   @see http://en.wikipedia.org/wiki/ISO_4217
  #
  # @!attribute negotiated_rate
  #   The negotiated rate in cents
  #   @return [Integer]
  #
  # @!attribute compare_price
  #   The comparable price in cents
  #   @return [Integer]
  #
  # @!attribute insurance_price
  #   The price of insurance in cents.
  #   @return [Integer]
  class RateEstimate
    attr_reader :origin, :destination, :package_rates,
                :carrier, :service_name, :service_code,
                :shipping_date, :delivery_date, :delivery_range,
                :currency, :negotiated_rate, :insurance_price,
                :estimate_reference, :expires_at, :pickup_time,
                :compare_price

    def initialize(origin, destination, carrier, service_name, options = {})
      @origin, @destination, @carrier, @service_name = origin, destination, carrier, service_name
      @service_code = options[:service_code]
      @estimate_reference = options[:estimate_reference]
      @pickup_time = options[:pickup_time]
      @expires_at = options[:expires_at]
      if options[:package_rates]
        @package_rates = options[:package_rates].map { |p| p.update(:rate => Package.cents_from(p[:rate])) }
      else
        @package_rates = Array(options[:packages]).map { |p| {:package => p} }
      end
      @total_price = Package.cents_from(options[:total_price])
      @negotiated_rate = options[:negotiated_rate] ? Package.cents_from(options[:negotiated_rate]) : nil
      @compare_price = options[:compare_price] ? Package.cents_from(options[:compare_price]) : nil
      @currency = ActiveUtils::CurrencyCode.standardize(options[:currency])
      @delivery_range = options[:delivery_range] ? options[:delivery_range].map { |date| date_for(date) }.compact : []
      @shipping_date = date_for(options[:shipping_date])
      @delivery_date = @delivery_range.last
      @insurance_price = Package.cents_from(options[:insurance_price])
    end

    # The total price of the shipments in cents.
    # @return [Integer]
    def total_price
      @total_price || @package_rates.sum { |pr| pr[:rate] }
    rescue NoMethodError
      raise ArgumentError.new("RateEstimate must have a total_price set, or have a full set of valid package rates.")
    end
    alias_method :price, :total_price

    # Adds a package to this rate estimate
    # @param package [ActiveShipping::Package] The package to add.
    # @param rate [#cents, Float, String, nil] The rate for this package. This is only required if
    #   there is no total price for this shipment
    # @return [self]
    def add(package, rate = nil)
      cents = Package.cents_from(rate)
      raise ArgumentError.new("New packages must have valid rate information since this RateEstimate has no total_price set.") if cents.nil? and total_price.nil?
      @package_rates << {:package => package, :rate => cents}
      self
    end

    # The list of packages for which rate estimates are given.
    # @return [Array<ActiveShipping::Package>]
    def packages
      package_rates.map { |p| p[:package] }
    end

    # The number of packages for which rate estimates are given.
    # @return [Integer]
    def package_count
      package_rates.length
    end

    private

    # Returns a Date object for a given input
    # @param [String, Date, Time, DateTime, ...] The object to infer a date from.
    # @return [Date, nil] The Date object absed on the input, or `nil` if no date
    #   could be determined.
    def date_for(date)
      date && DateTime.strptime(date.to_s, "%Y-%m-%d")
    rescue ArgumentError
      nil
    end
  end
end
